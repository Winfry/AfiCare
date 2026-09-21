// sync-kmpdc-register — refreshes the local kmpdc_practitioners mirror
// (029_kmpdc_practitioners.sql) from KMPDC's own PUBLIC practitioner
// register at registers.kmpdc.go.ke. NOT an official KMPDC API — KMPDC
// publishes no documented API; this reads the same public HTML page a
// human would when using their site's own "verify a practitioner" tool.
// Confirmed by hand (curl'd the raw HTML): each cadre's full register is
// delivered as one server-rendered <table id="dataTable"> in the initial
// page load — no separate JSON endpoint exists to call instead.
//
// Scoped to Medical Doctors + Dentists only (both share an identical
// 9-column layout: Index, Full Name, Registration No, Qualifications,
// Discipline, License Type, Specialty, Sub Specialty, Status — Specialty/
// Sub Specialty are not stored, out of scope for this table's schema).
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
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { DOMParser } from "https://deno.land/x/deno_dom@v0.1.45/deno-dom-wasm.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const STALE_AFTER_MS = 20 * 60 * 60 * 1000; // 20 hours

const CADRE_URLS: Record<string, string> = {
  medical_doctor: "https://registers.kmpdc.go.ke/localPractitioners/getLicensedMedicalPractitioners/",
  dentist: "https://registers.kmpdc.go.ke/localPractitioners/getLicensedDentalPractitioners/",
};

// Column order confirmed by hand against the live page's raw HTML.
const COL = {
  fullName: 1,
  registrationNo: 2,
  qualifications: 3,
  discipline: 4,
  licenseType: 5,
  status: 8,
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

interface ParsedRow {
  full_name: string;
  masked_registration_no: string;
  qualifications: string | null;
  discipline: string | null;
  license_type: string | null;
  status: string | null;
}

function parseCadrePage(html: string): ParsedRow[] {
  const doc = new DOMParser().parseFromString(html, "text/html");
  if (!doc) return [];
  const table = doc.querySelector("#dataTable");
  if (!table) return [];
  const rows: ParsedRow[] = [];
  const trs = table.querySelectorAll("tbody tr");
  for (const tr of Array.from(trs)) {
    const tds = (tr as unknown as { querySelectorAll: (s: string) => unknown[] }).querySelectorAll("td");
    const cells = Array.from(tds) as { textContent: string }[];
    if (cells.length < 9) continue; // skip malformed/empty rows
    const fullName = cells[COL.fullName]?.textContent?.trim() ?? "";
    const registrationNo = cells[COL.registrationNo]?.textContent?.trim() ?? "";
    if (!fullName || !registrationNo) continue;
    rows.push({
      full_name: fullName,
      masked_registration_no: registrationNo,
      qualifications: cells[COL.qualifications]?.textContent?.trim() || null,
      discipline: cells[COL.discipline]?.textContent?.trim() || null,
      license_type: cells[COL.licenseType]?.textContent?.trim() || null,
      status: cells[COL.status]?.textContent?.trim() || null,
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

    for (const [cadre, url] of Object.entries(CADRE_URLS)) {
      const res = await fetch(url, { headers: { "User-Agent": "Mozilla/5.0 (AfiCare verification sync)" } });
      if (!res.ok) {
        console.error(`kmpdc fetch failed for ${cadre}: ${res.status}`);
        continue; // best-effort per cadre -- one failing shouldn't block the other
      }
      const html = await res.text();
      const rows = parseCadrePage(html);
      if (rows.length === 0) {
        console.error(`kmpdc parse returned zero rows for ${cadre} -- likely a site structure change`);
        continue; // don't wipe existing good data with an empty result
      }

      await admin.from("kmpdc_practitioners").delete().eq("cadre", cadre);
      const toInsert = rows.map((r) => ({ ...r, cadre, synced_at: syncedAt }));
      // Insert in batches -- these pages run into the thousands of rows.
      const BATCH_SIZE = 500;
      for (let i = 0; i < toInsert.length; i += BATCH_SIZE) {
        const { error: insertErr } = await admin.from("kmpdc_practitioners").insert(toInsert.slice(i, i + BATCH_SIZE));
        if (insertErr) {
          console.error(`kmpdc insert failed for ${cadre} batch ${i}`, insertErr);
          break;
        }
      }
      syncedCounts[cadre] = rows.length;
    }

    return json({ ok: true, skipped: false, syncedCounts, syncedAt });
  } catch (e) {
    console.error("sync-kmpdc-register error", e);
    return json({ error: "Could not sync KMPDC register. Please try again." }, 500);
  }
});
