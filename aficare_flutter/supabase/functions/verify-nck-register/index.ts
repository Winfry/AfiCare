// verify-nck-register — checks a name against the Nursing Council of
// Kenya (NCK)'s PUBLIC "License Status" search at osp.nckenya.com. NOT
// an official API -- NCK publishes no documented API either, same as
// KMPDC -- but unlike KMPDC's registers, NCK's own site already IS a
// per-query search endpoint (confirmed by hand: drove the real page in
// a browser, captured the actual XHR, then reproduced it with a bare
// `curl` carrying zero cookies -- it needs no session/CSRF at all):
//
//   POST https://osp.nckenya.com/ajax/public
//   Content-Type: application/x-www-form-urlencoded
//   body: search_register=1&search_text=<name|license|id>
//
// This is structurally simpler than sync-kmpdc-register: there is no
// bulk register page to mirror, so there is no local table, no
// service-role writes, and no staleness gate. Every search is a live,
// on-demand call straight to NCK, parsed and returned directly.
//
// The response is a small server-rendered HTML fragment with a results
// table (Name, License Number, Status/Valid Till, View more). Parsed
// with the same plain-regex approach as sync-kmpdc-register (proven
// reliable there; a WASM DOM parser previously failed silently in this
// same runtime) -- and the table here is tiny per query, so it's even
// less work than KMPDC's bulk pages.
//
// One data-quality lesson carried over from KMPDC: a real NCK result
// came back as "JOHN KARANJA  NYOIKE" (double space) during hand
// testing -- whitespace is collapsed here at the source, the same fix
// applied to sync-kmpdc-register after 2,047 KMPDC rows were found with
// the same artifact.
//
// Mirrors sync-kmpdc-register's shape otherwise: inline CORS/json
// helpers, a caller-scoped client only to confirm the request comes
// from a signed-in AfiCare user, and debugLog() writing to audit_log at
// every stage for the same diagnosability that caught KMPDC's silent
// empty-table failure.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const NCK_SEARCH_URL = "https://osp.nckenya.com/ajax/public";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

interface NckResult {
  full_name: string;
  license_number: string;
  status: string | null;
  valid_till: string | null;
}

function decodeEntities(s: string): string {
  return s
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#0?39;/g, "'")
    .replace(/&nbsp;/g, " ");
}

function cellText(html: string): string {
  return decodeEntities(html.replace(/<[^>]*>/g, "")).replace(/\s+/g, " ").trim();
}

/// Splits NCK's combined "Status: Active   2027-09-30" cell into a
/// clean status word and a valid-till date -- confirmed by hand this is
/// always a status label followed by whitespace then a YYYY-MM-DD date.
function splitStatusCell(text: string): { status: string | null; validTill: string | null } {
  const statusMatch = text.match(/Status:\s*([A-Za-z]+)/);
  const dateMatch = text.match(/(\d{4}-\d{2}-\d{2})/);
  return {
    status: statusMatch ? statusMatch[1] : null,
    validTill: dateMatch ? dateMatch[1] : null,
  };
}

/// Parses NCK's search-results HTML fragment. No DOM library -- same
/// plain-regex approach as sync-kmpdc-register, and this fragment is
/// tiny (a handful of rows per query) compared to KMPDC's bulk pages.
function parseResults(html: string): NckResult[] {
  const results: NckResult[] = [];

  const tbodyOpen = html.indexOf("<tbody>");
  const tbodyClose = html.indexOf("</tbody>", tbodyOpen);
  if (tbodyOpen === -1 || tbodyClose === -1) return results;
  const tbodyHtml = html.slice(tbodyOpen + "<tbody>".length, tbodyClose);

  const trRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/g;
  let trMatch: RegExpExecArray | null;
  while ((trMatch = trRegex.exec(tbodyHtml)) !== null) {
    const tdRegex = /<td[^>]*>([\s\S]*?)<\/td>/g;
    const cells: string[] = [];
    let tdMatch: RegExpExecArray | null;
    while ((tdMatch = tdRegex.exec(trMatch[1])) !== null) {
      cells.push(cellText(tdMatch[1]));
    }
    // Name, License Number, Status/Valid Till, View more -- confirmed
    // by hand against a real response.
    if (cells.length < 3) continue;
    const fullName = cells[0];
    const licenseNumber = cells[1];
    if (!fullName || !licenseNumber) continue;
    const { status, validTill } = splitStatusCell(cells[2]);
    results.push({ full_name: fullName, license_number: licenseNumber, status, valid_till: validTill });
  }
  return results;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  async function debugLog(stage: string, data: unknown) {
    try {
      await admin.from("audit_log").insert({
        action: "nck_verify_debug",
        details: { stage, data: JSON.parse(JSON.stringify(data)) },
        timestamp: new Date().toISOString(),
      });
    } catch (_e) {
      // best-effort only
    }
  }

  try {
    const { data: callerUser, error: callerErr } = await caller.auth.getUser();
    if (callerErr || !callerUser.user) {
      return json({ error: "Not authenticated." }, 401);
    }

    let body: { name?: string };
    try {
      body = await req.json();
    } catch (_e) {
      return json({ error: "Invalid request body." }, 400);
    }
    const name = (body.name ?? "").trim().replace(/\s+/g, " ");
    if (!name) return json({ error: "name is required." }, 400);

    let res: Response;
    try {
      res = await fetch(NCK_SEARCH_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "X-Requested-With": "XMLHttpRequest",
          "User-Agent": "Mozilla/5.0 (AfiCare verification)",
        },
        body: new URLSearchParams({ search_register: "1", search_text: name }).toString(),
      });
    } catch (fetchErr) {
      await debugLog("fetch_exception", { name, message: (fetchErr as Error)?.message ?? String(fetchErr) });
      return json({ error: "Could not reach NCK's register. Please try again." }, 502);
    }
    if (!res.ok) {
      await debugLog("fetch_not_ok", { name, status: res.status });
      return json({ error: "Could not reach NCK's register. Please try again." }, 502);
    }

    const html = await res.text();
    const results = parseResults(html);
    await debugLog("parsed", { name, rowCount: results.length });

    return json({ ok: true, results });
  } catch (e) {
    console.error("verify-nck-register error", e);
    await debugLog("uncaught_exception", { message: (e as Error)?.message ?? String(e) });
    return json({ error: "Could not check NCK's register. Please try again." }, 500);
  }
});
