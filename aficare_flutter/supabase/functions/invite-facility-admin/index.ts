// invite-facility-admin — the only place a facility_admin account is
// ever created. Called by a platform admin approving a
// facility_admin_requests row. Creates the auth account and sends the
// real invite email via Supabase's native inviteUserByEmail (nothing
// to build for delivery), then creates the matching public.users row
// directly as role='facility_admin' via service_create_invited_
// facility_admin (017_facility_admin_invite_flow.sql) — the account
// never exists as 'patient', not even briefly, unlike a client-side
// insert which enforce_role_status_lock would force to 'patient'.
//
// Mirrors patient-auth's shape: inline CORS/json helpers, service-role
// admin client, rollback the auth user on any downstream failure.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
// The deployed app's own URL (not the Supabase URL) — where the invite
// email's link should land. Set via `supabase secrets set APP_BASE_URL=...`.
// Falls back to the local dev server used during this build's testing.
const APP_BASE_URL = Deno.env.get("APP_BASE_URL") ?? "http://localhost:8765";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function isNonEmptyString(v: unknown): v is string {
  return typeof v === "string" && v.trim().length > 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing Authorization header" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request body" }, 400);
  }

  const { requestId, email, fullName, facilityId, title } = body;
  if (
    !isNonEmptyString(requestId) ||
    !isNonEmptyString(email) ||
    !isNonEmptyString(fullName) ||
    !isNonEmptyString(facilityId)
  ) {
    return json({ error: "requestId, email, fullName and facilityId are required." }, 400);
  }
  const targetTitle = typeof title === "string" && title.trim() ? title.trim() : null;

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  // Scoped to the caller's own session — used only to verify they're
  // really a platform admin before anything privileged happens. The
  // SQL function this calls into has no permission check of its own;
  // this is the real gate.
  const caller = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  // Diagnostic trail written directly to the DB (service-role client
  // bypasses RLS) since Edge Function console logs aren't reachable
  // from this environment's CLI. Remove once the ghost-account bug
  // (public.users row created with no backing auth.users row) is
  // root-caused. Best-effort: never let a logging failure break the
  // real flow.
  async function debugLog(stage: string, data: unknown) {
    try {
      await admin.from("audit_log").insert({
        action: "invite_debug",
        details: { stage, requestId, email, data: JSON.parse(JSON.stringify(data)) },
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

    const { data: role, error: roleErr } = await caller.rpc("get_my_role");
    if (roleErr || role !== "admin") {
      return json({ error: "Only the platform admin can approve facility admin requests." }, 403);
    }

    await debugLog("before_invite", { callerId: callerUser.user.id });

    // redirectTo must NOT embed a "#/..." path: this app uses
    // HashUrlStrategy for its own routing, and Supabase's PKCE flow
    // appends "?code=..." as a real query string on the redirect. If
    // redirectTo already contains a "#", that "?code=..." lands inside
    // the hash fragment instead of window.location.search, where
    // supabase_flutter's detectSessionInUrl never finds it -- no
    // session gets established client-side. Landing at the bare origin
    // lets the SDK exchange the code first; the router's own
    // status == invited gate (see router.dart) then sends the user to
    // /accept-invite once the session/profile loads.
    const { data: invited, error: inviteErr } = await admin.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName },
      redirectTo: APP_BASE_URL,
    });

    await debugLog("after_invite", {
      hasError: !!inviteErr,
      errorMessage: inviteErr?.message ?? null,
      errorStatus: (inviteErr as { status?: number } | null)?.status ?? null,
      hasUser: !!invited?.user,
      userId: invited?.user?.id ?? null,
      userEmail: invited?.user?.email ?? null,
    });

    if (inviteErr || !invited?.user) {
      console.error("inviteUserByEmail failed", inviteErr);
      return json({ error: inviteErr?.message ?? "Could not send the invite. Please try again." }, 500);
    }
    const newUserId = invited.user.id;

    // Verify the auth user is actually visible before we ever attach
    // public data to its id — catches exactly the ghost-account case
    // where inviteUserByEmail() resolves with a user object but no
    // row is really there (yet, or at all).
    const { data: verifyUser, error: verifyErr } = await admin.auth.admin.getUserById(newUserId);
    await debugLog("verify_user", {
      hasError: !!verifyErr,
      errorMessage: verifyErr?.message ?? null,
      found: !!verifyUser?.user,
    });
    if (verifyErr || !verifyUser?.user) {
      console.error("invited user not retrievable immediately after invite", verifyErr);
      return json({ error: "Invite creation did not complete cleanly. Please try again." }, 500);
    }

    const { error: createErr } = await admin.rpc("service_create_invited_facility_admin", {
      new_user_id: newUserId,
      new_email: email,
      new_full_name: fullName,
      target_facility_id: facilityId,
      target_title: targetTitle,
      request_id: requestId,
      invited_by: callerUser.user.id,
    });

    await debugLog("after_rpc", { hasError: !!createErr, errorMessage: createErr?.message ?? null });

    if (createErr) {
      // A duplicate-key failure here means a concurrent call for this
      // same request already finished successfully (e.g. the Approve
      // button was tapped twice) -- newUserId already has a real
      // public.users row. Deleting it would destroy that earlier
      // success, not roll back a failure. Treat it as success instead
      // of calling deleteUser.
      if (createErr.message?.includes("duplicate key")) {
        console.warn("service_create_invited_facility_admin: duplicate call, treating as success", createErr);
        return json({ ok: true, user_id: newUserId });
      }
      await admin.auth.admin.deleteUser(newUserId).catch(() => {});
      console.error("service_create_invited_facility_admin failed", createErr);
      return json({ error: "Could not finish setting up the account. Please try again." }, 500);
    }

    return json({ ok: true, user_id: newUserId });
  } catch (e) {
    console.error("invite-facility-admin error", e);
    await debugLog("uncaught_exception", { message: (e as Error)?.message ?? String(e) });
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});
