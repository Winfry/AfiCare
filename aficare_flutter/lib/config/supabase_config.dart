/// Supabase Configuration
/// Replace these with your actual Supabase project credentials
/// Get them from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/api
class SupabaseConfig {
  static const String url = 'https://uxphfdezypgshgfklcky.supabase.co';

  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InV4cGhmZGV6eXBnc2hnZmtsY2t5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyOTAxMzcsImV4cCI6MjA4NTg2NjEzN30.tv4-MxEIWK9cBKxuvYPKbSSlE32zFpDVOnXnn_TN7Co';

  // Table names
  static const String usersTable = 'users';
  static const String patientsTable = 'patients';
  static const String consultationsTable = 'consultations';
  static const String accessCodesTable = 'access_codes';
  static const String auditLogTable = 'audit_log';
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
