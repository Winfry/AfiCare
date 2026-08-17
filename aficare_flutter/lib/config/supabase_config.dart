/// Supabase Configuration
/// Replace these with your actual Supabase project credentials
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
class SupabaseConfig {
  static const String url = 'https://jjzfozfsswvemgdptfdk.supabase.co';

  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpqemZvemZzc3d2ZW1nZHB0ZmRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQxNjQ2MDQsImV4cCI6MjA5OTc0MDYwNH0.gRmCQFxFOE06uSqSt0e5xKk_rk_Fkn4-zEEYiW6HArc';

  /// App-side secret used to derive the Supabase auth password from a
  /// patient's phone + PIN. This is NOT a true server-side secret (any
  /// client app can be reverse-engineered), but combined with the user's
  /// 6-digit PIN it means a database leak alone cannot recover passwords.
  /// Change this to a unique random string for your deployment.
  static const String patientAuthSecret =
      'aficare-patient-pin-v1-9f3a7c2e8b1d4f6a';

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
