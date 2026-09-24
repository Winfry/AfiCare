-- Provider Profile Photo Upload -- lets a doctor/nurse/etc. upload a
-- real photo of themselves. The ProviderAvatar widget
-- (lib/widgets/provider_avatar.dart) was already built anticipating
-- this: its resolution order already tries a real photoUrl FIRST,
-- before the cartoon-illustration/initials fallbacks -- nothing has
-- ever populated it until now.
--
-- No new RLS needed on `users` itself: the existing policy
-- ("Users can update own profile", auth.uid() = id) already lets any
-- authenticated user update their own row directly, and
-- enforce_role_status_lock (010_role_escalation_fix.sql) only blocks
-- role/status changes, not other columns -- photo_url slots straight
-- into the existing AuthProvider.updateProfile()-style direct update.
--
-- A dedicated `provider-photos` bucket (not the existing `media`
-- bucket used for receipts) with its own tracked RLS -- the `media`
-- bucket's policies were set up via the dashboard and are untracked in
-- any migration; this doesn't repeat that gap. Public-read (patients/
-- facility-admins need to see these), owner-write via the standard
-- Supabase Storage folder-ownership check.

BEGIN;

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS photo_url TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('provider-photos', 'provider-photos', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "provider_photos_public_read" ON storage.objects
FOR SELECT USING (bucket_id = 'provider-photos');

CREATE POLICY "provider_photos_owner_write" ON storage.objects
FOR INSERT WITH CHECK (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "provider_photos_owner_update" ON storage.objects
FOR UPDATE USING (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "provider_photos_owner_delete" ON storage.objects
FOR DELETE USING (
  bucket_id = 'provider-photos' AND (storage.foldername(name))[1] = auth.uid()::text
);

COMMIT;

-- ================================================================
-- VERIFY (run manually, not part of the migration):
--
-- A user can write into their OWN folder:
--   (from the app, or via storage.objects insert as that user) path
--   'provider-photos/<own-user-id>/photo.jpg' -- succeeds
--
-- A user CANNOT write into someone else's folder:
--   path 'provider-photos/<other-user-id>/photo.jpg' -- fails
--
-- Anyone (including anonymous/public) can read any photo in the bucket:
--   SELECT * FROM storage.objects WHERE bucket_id = 'provider-photos';
--   -- readable regardless of who owns the row
--
-- A plain profile update including photo_url succeeds for the row owner:
--   UPDATE users SET photo_url = 'https://...' WHERE id = auth.uid(); -- succeeds
--   UPDATE users SET photo_url = 'https://...' WHERE id = '<other-user-id>'; -- fails (RLS)
-- ================================================================
