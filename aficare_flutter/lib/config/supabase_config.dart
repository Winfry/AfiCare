/// Supabase Configuration
/// Replace these with your actual Supabase project credentials
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
class SupabaseConfig {
  static const String url = 'https://jjzfozfsswvemgdptfdk.supabase.co';

  // Supabase's newer "publishable key" format — replaces the legacy
  // JWT-shaped anon key, which the project's Edge Functions gateway now
  // rejects outright. Safe to keep in source (it's the public-facing key,
  // access is still governed entirely by RLS policies on each table).
  static const String anonKey = 'sb_publishable_WkPCejAjYiUGx8WeoOC4lw_NoxsQrpP';

  // Patient PIN registration/login is handled entirely server-side by the
  // `patient-auth` Edge Function (see supabase/functions/patient-auth).
  // The PIN hash and the password-derivation secret never reach the
  // client — see AuthProvider.signUpPatientDirect / signInWithPhoneAndPin.

  // Table names
  static const String usersTable = 'users';
  static const String patientsTable = 'patients';
  static const String consultationsTable = 'consultations';
  static const String accessCodesTable = 'access_codes';
  static const String auditLogTable = 'audit_log';
  static const String expensesTable = 'medical_expenses';
}

/// Instructions to set up Supabase (FREE):
///
/// 1. Go to https://supabase.com and create a free account
/// 2. Create a new project (free tier allows 2 projects)
/// 3. Go to Settings > API
/// 4. Copy the "URL" and "anon public" key
/// 5. Replace the values above
///
/// Free Tier Includes:
/// - 500 MB Database
/// - 1 GB Storage
/// - 50,000 monthly active users
/// - Unlimited API requests
