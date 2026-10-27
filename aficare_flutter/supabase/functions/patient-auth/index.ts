// patient-auth — server-side patient PIN registration & login.
//
// Replaces the old client-side flow where the app fetched a bcrypt PIN
// hash via the anon key and derived the Supabase auth password using a
// secret compiled into the app binary. Both the PIN hash and the
// derivation secret now live only here: the hash in `patient_credentials`
// (RLS on, zero policies — reachable only by the service-role key this
// function holds), the secret as a Supabase Function secret that is
// never shipped to any client.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.45.4";
import bcrypt from "npm:bcryptjs@2.4.3";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const AUTH_SECRET = Deno.env.get("PATIENT_AUTH_SECRET");

const MAX_ATTEMPTS = 5;
const LOCKOUT_MINUTES = 15;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Never reveals whether the phone number is registered, which field was
// wrong, or that an account is locked — a single generic message for
// every failure case so the response can't be used to enumerate accounts.
const GENERIC_ERROR = "Invalid phone number or PIN.";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

async function derivePassword(phone: string, pin: string): Promise<string> {
  const data = new TextEncoder().encode(`${phone}:${pin}:${AUTH_SECRET}`);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 32);
}

function isValidPin(pin: unknown): pin is string {
  return typeof pin === "string" && /^\d{6}$/.test(pin);
}

function isValidPhone(phone: unknown): phone is string {
  return typeof phone === "string" && phone.trim().length >= 7;
}

// Phones are stored as +254 followed by 9 digits (PhoneFormatter in the
// app). A changed number must be in the same form, or the login lookup
// by phone would never find it again.
function isKenyanE164(phone: unknown): phone is string {
  return typeof phone === "string" && /^\+254\d{9}$/.test(phone);
}

function generateMedilinkId(): string {
  const digits = Math.floor(100000 + Math.random() * 900000);
  return `ML-NBO-${digits}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!AUTH_SECRET) {
    console.error("PATIENT_AUTH_SECRET is not set — run `supabase secrets set PATIENT_AUTH_SECRET=<value>`");
    return json({ error: "Server misconfigured. Contact support." }, 500);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request body" }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const anon = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  try {
    if (body.action === "register") return await handleRegister(body, admin, anon);
    if (body.action === "login") return await handleLogin(body, admin, anon);
    if (body.action === "change_phone") return await handleChangePhone(req, body, admin);
    if (body.action === "change_pin") return await handleChangePin(req, body, admin);
    return json({ error: "Unknown action" }, 400);
  } catch (e) {
    console.error("patient-auth error", e);
    return json({ error: "Something went wrong. Please try again." }, 500);
  }
});

async function handleRegister(
  body: Record<string, unknown>,
  admin: SupabaseClient,
  anon: SupabaseClient,
): Promise<Response> {
  const { phone, pin, fullName } = body;

  if (!isValidPhone(phone) || !isValidPin(pin) || typeof fullName !== "string" || !fullName.trim()) {
    return json({ error: "Phone, 6-digit PIN and full name are required." }, 400);
  }

  const { data: existing } = await admin.from("users").select("id").eq("phone", phone).maybeSingle();
  if (existing) {
    return json({ error: "An account with this phone number already exists. Please log in instead." }, 409);
  }

  const placeholderEmail = `${phone.replace(/\+/g, "")}@patient.aficare`;
  const password = await derivePassword(phone, pin);

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email: placeholderEmail,
    password,
    email_confirm: true,
  });
  if (createErr || !created.user) {
    console.error("createUser failed", createErr);
    return json({ error: "Could not create account. Please try again." }, 500);
  }
  const userId = created.user.id;

  const { error: profileErr } = await admin.from("users").insert({
    id: userId,
    email: placeholderEmail,
    full_name: fullName,
    role: "patient",
    phone,
    medilink_id: generateMedilinkId(),
    created_at: new Date().toISOString(),
  });
  if (profileErr) {
    await admin.auth.admin.deleteUser(userId).catch(() => {});
    console.error("profile insert failed", profileErr);
    return json({ error: "Could not save your profile. Please try again." }, 500);
  }

  const pinHash = bcrypt.hashSync(pin, 12);
  const { error: credErr } = await admin.from("patient_credentials").insert({ user_id: userId, pin_hash: pinHash });
  if (credErr) {
    await admin.auth.admin.deleteUser(userId).catch(() => {});
    await admin.from("users").delete().eq("id", userId);
    console.error("credentials insert failed", credErr);
    return json({ error: "Could not save your profile. Please try again." }, 500);
  }

  const { data: signInData, error: signInErr } = await anon.auth.signInWithPassword({
    email: placeholderEmail,
    password,
  });
  if (signInErr || !signInData.session) {
    console.error("post-register sign-in failed", signInErr);
    return json({ registered: true, error: "Account created — please log in." }, 201);
  }

  return json({
    access_token: signInData.session.access_token,
    refresh_token: signInData.session.refresh_token,
    user_id: userId,
  });
}

async function handleLogin(
  body: Record<string, unknown>,
  admin: SupabaseClient,
  anon: SupabaseClient,
): Promise<Response> {
  const { phone, pin } = body;
  if (!isValidPhone(phone) || !isValidPin(pin)) {
    return json({ error: GENERIC_ERROR }, 400);
  }

  const { data: user } = await admin.from("users").select("id, email").eq("phone", phone).maybeSingle();
  if (!user) return json({ error: GENERIC_ERROR }, 401);

  const { data: cred } = await admin
    .from("patient_credentials")
    .select("pin_hash, failed_attempts, locked_until")
    .eq("user_id", user.id)
    .maybeSingle();
  if (!cred) return json({ error: GENERIC_ERROR }, 401);

  if (cred.locked_until && new Date(cred.locked_until) > new Date()) {
    return json({ error: "Too many attempts. Please try again in a few minutes." }, 429);
  }

  const isValid = bcrypt.compareSync(pin, cred.pin_hash);
  if (!isValid) {
    const attempts = (cred.failed_attempts ?? 0) + 1;
    const update: Record<string, unknown> = { failed_attempts: attempts, updated_at: new Date().toISOString() };
    if (attempts >= MAX_ATTEMPTS) {
      update.locked_until = new Date(Date.now() + LOCKOUT_MINUTES * 60_000).toISOString();
      update.failed_attempts = 0;
    }
    await admin.from("patient_credentials").update(update).eq("user_id", user.id);
    return json({ error: GENERIC_ERROR }, 401);
  }

  if (cred.failed_attempts > 0 || cred.locked_until) {
    await admin
      .from("patient_credentials")
      .update({ failed_attempts: 0, locked_until: null, updated_at: new Date().toISOString() })
      .eq("user_id", user.id);
  }

  const password = await derivePassword(phone, pin);
  const { data: signInData, error: signInErr } = await anon.auth.signInWithPassword({
    email: user.email,
    password,
  });
  if (signInErr || !signInData.session) {
    console.error("sign-in after PIN verify failed", signInErr);
    return json({ error: GENERIC_ERROR }, 401);
  }

  return json({
    access_token: signInData.session.access_token,
    refresh_token: signInData.session.refresh_token,
    user_id: user.id,
  });
}

// ── Changing the phone number or PIN of a signed-in patient ─────────
//
// The Supabase password of a PIN account is derived from phone + PIN, and
// login finds the account by phone. So both can only change here, where
// the password is re-derived in the same step. Changing users.phone any
// other way would lock the patient out for good (039 blocks it).

type PinCheck = "ok" | "wrong" | "locked" | "none";

// Same PIN check and lockout as login: a wrong PIN counts toward the
// five-attempt limit, so these actions can't be used to guess a PIN.
async function checkPin(admin: SupabaseClient, userId: string, pin: string): Promise<PinCheck> {
  const { data: cred } = await admin
    .from("patient_credentials")
    .select("pin_hash, failed_attempts, locked_until")
    .eq("user_id", userId)
    .maybeSingle();
  if (!cred) return "none";
  if (cred.locked_until && new Date(cred.locked_until) > new Date()) return "locked";

  if (!bcrypt.compareSync(pin, cred.pin_hash)) {
    const attempts = (cred.failed_attempts ?? 0) + 1;
    const update: Record<string, unknown> = { failed_attempts: attempts, updated_at: new Date().toISOString() };
    if (attempts >= MAX_ATTEMPTS) {
      update.locked_until = new Date(Date.now() + LOCKOUT_MINUTES * 60_000).toISOString();
      update.failed_attempts = 0;
    }
    await admin.from("patient_credentials").update(update).eq("user_id", userId);
    return "wrong";
  }

  if (cred.failed_attempts > 0 || cred.locked_until) {
    await admin
      .from("patient_credentials")
      .update({ failed_attempts: 0, locked_until: null, updated_at: new Date().toISOString() })
      .eq("user_id", userId);
  }
  return "ok";
}

function pinCheckError(result: PinCheck): Response {
  if (result === "locked") return json({ error: "Too many attempts. Please try again in a few minutes." }, 429);
  if (result === "none") return json({ error: "This account doesn't sign in with a PIN." }, 400);
  return json({ error: "That PIN is not right." }, 401);
}

// The signed-in caller, from the access token the app sends.
async function callerId(req: Request, admin: SupabaseClient): Promise<string | null> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user.id;
}

async function handleChangePhone(
  req: Request,
  body: Record<string, unknown>,
  admin: SupabaseClient,
): Promise<Response> {
  const userId = await callerId(req, admin);
  if (!userId) return json({ error: "Please log in again." }, 401);

  const { pin, newPhone } = body;
  if (!isValidPin(pin)) return json({ error: "Enter your 6-digit PIN." }, 400);
  if (!isKenyanE164(newPhone)) return json({ error: "Enter a valid Kenyan phone number." }, 400);

  const { data: user } = await admin.from("users").select("id, phone").eq("id", userId).maybeSingle();
  if (!user) return json({ error: "Please log in again." }, 401);

  const pinResult = await checkPin(admin, userId, pin);
  if (pinResult !== "ok") return pinCheckError(pinResult);

  if (user.phone === newPhone) return json({ ok: true, phone: newPhone });

  const { data: taken } = await admin.from("users").select("id").eq("phone", newPhone).neq("id", userId).maybeSingle();
  if (taken) return json({ error: "That phone number is already used by another account." }, 409);

  // Phone first, then the password. If the password step fails the phone
  // goes back, so the old phone + PIN still work: never half-changed.
  const { error: phoneErr } = await admin.from("users").update({ phone: newPhone }).eq("id", userId);
  if (phoneErr) {
    console.error("change_phone: phone update failed", phoneErr);
    return json({ error: "Could not change your phone number. Please try again." }, 500);
  }

  const { error: pwErr } = await admin.auth.admin.updateUserById(userId, {
    password: await derivePassword(newPhone, pin),
  });
  if (pwErr) {
    console.error("change_phone: password update failed", pwErr);
    await admin.from("users").update({ phone: user.phone }).eq("id", userId);
    return json({ error: "Could not change your phone number. Please try again." }, 500);
  }

  return json({ ok: true, phone: newPhone });
}

async function handleChangePin(
  req: Request,
  body: Record<string, unknown>,
  admin: SupabaseClient,
): Promise<Response> {
  const userId = await callerId(req, admin);
  if (!userId) return json({ error: "Please log in again." }, 401);

  const { currentPin, newPin } = body;
  if (!isValidPin(currentPin)) return json({ error: "Enter your current 6-digit PIN." }, 400);
  if (!isValidPin(newPin)) return json({ error: "Your new PIN must be 6 digits." }, 400);
  if (currentPin === newPin) return json({ error: "Your new PIN is the same as your current one." }, 400);

  const { data: user } = await admin.from("users").select("id, phone").eq("id", userId).maybeSingle();
  if (!user?.phone) return json({ error: "Please log in again." }, 401);

  const pinResult = await checkPin(admin, userId, currentPin);
  if (pinResult !== "ok") return pinCheckError(pinResult);

  // Password first, then the stored PIN. If saving the PIN fails the
  // password goes back, so the current PIN keeps working.
  const { error: pwErr } = await admin.auth.admin.updateUserById(userId, {
    password: await derivePassword(user.phone, newPin),
  });
  if (pwErr) {
    console.error("change_pin: password update failed", pwErr);
    return json({ error: "Could not change your PIN. Please try again." }, 500);
  }

  const { error: credErr } = await admin
    .from("patient_credentials")
    .update({ pin_hash: bcrypt.hashSync(newPin, 12), updated_at: new Date().toISOString() })
    .eq("user_id", userId);
  if (credErr) {
    console.error("change_pin: pin_hash update failed", credErr);
    await admin.auth.admin.updateUserById(userId, { password: await derivePassword(user.phone, currentPin) });
    return json({ error: "Could not change your PIN. Please try again." }, 500);
  }

  return json({ ok: true });
}
