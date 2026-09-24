// sync-kmpdc-register — refreshes the local kmpdc_practitioners mirror
// (029_kmpdc_practitioners.sql) from KMPDC's own PUBLIC practitioner
// register at registers.kmpdc.go.ke. NOT an official KMPDC API — KMPDC
// publishes no documented API; this reads the same public HTML page a
// human would when using their site's own "verify a practitioner" tool.
// Confirmed by hand (curl'd the raw HTML): each cadre's full register is
// delivered as one server-rendered <table id="dataTable"> in the initial
// page load — no separate JSON endpoint exists to call instead.
//
// Covers 4 cadres: Medical Doctors + Dentists (identical 9-column
// layout: Index, Full Name, Registration No, Qualifications, Discipline,
// License Type, Specialty, Sub Specialty, Status — Specialty/Sub
// Specialty are not stored) and Medical/Dental Interns (a COMPLETELY
// DIFFERENT 5-column layout confirmed by fetching the live pages:
// Index, Full Name, Postal Address, Cadre, Course — KMPDC publishes NO
// registration number, license type or status for interns at all, so
// those columns are simply absent for this pair of cadres, not just
// empty). Each cadre therefore has its own column map (CADRES below)
// rather than one shared COL constant.
//
// Rate-limited at the function level, not via a cron schedule (this repo
// has no pg_cron/pg_net anywhere) — if the mirror was refreshed within
// the last ~20 hours, this returns immediately without touching KMPDC's
// site at all, regardless of how often the Flutter app calls it. This is
// the real safeguard against hammering a government site without a
// formal agreement in place.
//
// Mirrors invite-facility-admin's shape: inline CORS/json helpers,
// service-role client for the actual writes (kmpdc_practitioners has no
// INSERT/UPDATE/DELETE policy for anyone else), a caller-scoped client
// only to confirm the request comes from a signed-in AfiCare user (any
// role — this function only ever does harmless reads/writes to public
// reference data, so it isn't gated to a specific role like the
// facility-admin/platform-admin RPCs elsewhere in this app).
//
// Parsing is plain regex, NOT a DOM library. An earlier version used
// deno_dom (a WASM-based DOMParser) and shipped without ever being
// verified end-to-end against KMPDC's real pages from inside a deployed
// Edge Function -- only against small local mocks. In production the
// mirror table stayed completely empty (confirmed via `supabase db
// query`: zero rows, for every cadre, after real user traffic) --
// almost certainly the WASM parser failing to load or exceeding the
// Edge Function's CPU-time budget against the Medical Doctors page
// (confirmed by hand to be large enough that even a full desktop
// browser struggled to render it). The regex approach removes the WASM
// dependency and the full-DOM-tree-construction cost entirely, which
// matters given KMPDC's own table structure is simple and consistent
// (confirmed by hand: plain `<tr><td>text</td>...</tr>`, no nested
// markup inside a cell) -- there's nothing here that actually needs a
// real DOM parser.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STALE_AFTER_MS = 20 * 60 * 60 * 1000; // 20 hours

interface CadreConfig {
  url: string;
  fullName: number;
  // null = this cadre's page has no such column at all (not just blank).
  registrationNo: number | null;
  qualifications: number | null;
  discipline: number | null;
  licenseType: number | null;
  status: number | null;
  // Rows with fewer cells than this are skipped as malformed/empty.
  minCells: number;
}

// Every column index confirmed by hand against each page's live raw HTML.
const CADRES: Record<string, CadreConfig> = {
  medical_doctor: {
    url: "https://registers.kmpdc.go.ke/localPractitioners/getLicensedMedicalPractitioners/",
    fullName: 1, registrationNo: 2, qualifications: 3, discipline: 4, licenseType: 5, status: 8, minCells: 9,
  },
  dentist: {
    url: "https://registers.kmpdc.go.ke/localPractitioners/getLicensedDentalPractitioners/",
    fullName: 1, registrationNo: 2, qualifications: 3, discipline: 4, licenseType: 5, status: 8, minCells: 9,
  },
  medical_intern: {
    url: "https://registers.kmpdc.go.ke/internship/viewMedicalInterns/",
    // Index(0), Full Name(1), Postal Address(2, unused), Cadre(3), Course(4).
    fullName: 1, registrationNo: null, qualifications: 4, discipline: 3, licenseType: null, status: null, minCells: 5,
  },
  dental_intern: {
    url: "https://registers.kmpdc.go.ke/internship/viewDentalInterns/",
    fullName: 1, registrationNo: null, qualifications: 4, discipline: 3, licenseType: null, status: null, minCells: 5,
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

interface ParsedRow {
  full_name: string;
  masked_registration_no: string | null;
  qualifications: string | null;
  discipline: string | null;
  license_type: string | null;
  status: string | null;
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

function cellAt(cells: string[], idx: number | null): string | null {
  if (idx === null) return null;
  const v = cells[idx];
  return v && v.length > 0 ? v : null;
}

/// Extracts just the #dataTable's <tbody>...</tbody> (skipping the
/// repeated header/footer <tr> rows, which share the same cell shape
/// and would otherwise parse as bogus data rows), then walks each
/// <tr>/<td> with a plain regex -- no DOM construction at all.
function parseCadrePage(html: string, config: CadreConfig): ParsedRow[] {
  const rows: ParsedRow[] = [];

  const tableStart = html.indexOf('id="dataTable"');
  if (tableStart === -1) return rows;
  const tbodyOpen = html.indexOf("<tbody>", tableStart);
  const tbodyClose = html.indexOf("</tbody>", tbodyOpen);
  if (tbodyOpen === -1 || tbodyClose === -1) return rows;
  const tbodyHtml = html.slice(tbodyOpen + "<tbody>".length, tbodyClose);

  const trRegex = /<tr[^>]*>([\s\S]*?)<\/tr>/g;
  let trMatch: RegExpExecArray | null;
  while ((trMatch = trRegex.exec(tbodyHtml)) !== null) {
    const tdRegex = /<td[^>]*>([\s\S]*?)<\/td>/g;
    const cells: string[] = [];
    let tdMatch: RegExpExecArray | null;
    while ((tdMatch = tdRegex.exec(trMatch[1])) !== null) {
      cells.push(decodeEntities(tdMatch[1].replace(/<[^>]*>/g, "")).trim());
    }
    if (cells.length < config.minCells) continue; // skip malformed/empty rows

    const fullName = cellAt(cells, config.fullName) ?? "";
    if (!fullName) continue;
    // registrationNo is only required when this cadre actually has that
    // column (doctors/dentists) -- interns legitimately have none.
    if (config.registrationNo !== null && !cellAt(cells, config.registrationNo)) continue;

    rows.push({
      full_name: fullName,
      masked_registration_no: cellAt(cells, config.registrationNo),
      qualifications: cellAt(cells, config.qualifications),
      discipline: cellAt(cells, config.discipline),
      license_type: cellAt(cells, config.licenseType),
      status: cellAt(cells, config.status),
    });
  }
  return rows;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  // Only used to confirm the caller is a real, signed-in AfiCare user --
  // the SQL side has no permission check of its own for this table's
  // reads, but an Edge Function shouldn't be callable by a fully
  // anonymous request either.
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  // Diagnostic trail written directly to the DB (service-role client
  // bypasses RLS) -- the exact gap that let the previous, silently-
  // empty-forever sync go unnoticed. Best-effort: never let a logging
  // failure break the real flow.
  async function debugLog(stage: string, data: unknown) {
    try {
      await admin.from("audit_log").insert({
        action: "kmpdc_sync_debug",
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

    const { data: freshest } = await admin
      .from("kmpdc_practitioners")
      .select("synced_at")
      .order("synced_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (freshest?.synced_at) {
      const age = Date.now() - new Date(freshest.synced_at as string).getTime();
      if (age < STALE_AFTER_MS) {
        return json({ ok: true, skipped: true, lastSyncedAt: freshest.synced_at });
      }
    }

    const syncedAt = new Date().toISOString();
    const syncedCounts: Record<string, number> = {};

    for (const [cadre, config] of Object.entries(CADRES)) {
      let res: Response;
      try {
        res = await fetch(config.url, { headers: { "User-Agent": "Mozilla/5.0 (AfiCare verification sync)" } });
      } catch (fetchErr) {
        await debugLog("fetch_exception", { cadre, message: (fetchErr as Error)?.message ?? String(fetchErr) });
        continue;
      }
      if (!res.ok) {
        await debugLog("fetch_not_ok", { cadre, status: res.status });
        continue; // best-effort per cadre -- one failing shouldn't block the others
      }
      const html = await res.text();
      await debugLog("fetched", { cadre, htmlLength: html.length });

      const rows = parseCadrePage(html, config);
      await debugLog("parsed", { cadre, rowCount: rows.length });
      if (rows.length === 0) {
        await debugLog("zero_rows_skip", { cadre, htmlSnippet: html.slice(0, 500) });
        continue; // don't wipe existing good data with an empty result
      }

      await admin.from("kmpdc_practitioners").delete().eq("cadre", cadre);
      const toInsert = rows.map((r) => ({ ...r, cadre, synced_at: syncedAt }));
      // Insert in batches -- these pages run into the thousands of rows.
      const BATCH_SIZE = 500;
      let insertedForCadre = 0;
      for (let i = 0; i < toInsert.length; i += BATCH_SIZE) {
        const { error: insertErr } = await admin.from("kmpdc_practitioners").insert(toInsert.slice(i, i + BATCH_SIZE));
        if (insertErr) {
          await debugLog("insert_failed", { cadre, batchStart: i, message: insertErr.message });
          break;
        }
        insertedForCadre += toInsert.slice(i, i + BATCH_SIZE).length;
      }
      syncedCounts[cadre] = insertedForCadre;
    }

    await debugLog("sync_complete", { syncedCounts });
    return json({ ok: true, skipped: false, syncedCounts, syncedAt });
  } catch (e) {
    console.error("sync-kmpdc-register error", e);
    await debugLog("uncaught_exception", { message: (e as Error)?.message ?? String(e) });
    return json({ error: "Could not sync KMPDC register. Please try again." }, 500);
  }
});
