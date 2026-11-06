import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A patient's profile photo, kept private.
///
/// Doctors' photos live in the public `provider-photos` bucket so anyone
/// booking can see them. A patient's face is health-record territory, so
/// hers goes in the private `patient-photos` bucket (054), readable only
/// by her, her guardian and the clinicians caring for her. `users.photo_url`
/// then holds where the photo is (`patient-photos/<id>/photo`), never a
/// link anyone could open; each viewer gets a short-lived signed link.
class PatientPhotoService {
  PatientPhotoService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  static const bucket = 'patient-photos';
  static const _prefix = '$bucket/';

  /// How long a signed link works. Long enough to look at a page; the
  /// cache below asks for a new one well before it runs out.
  static const _linkLife = Duration(hours: 1);

  /// Signed links already made, so every avatar on a page doesn't ask the
  /// server again. Keyed by the stored value.
  static final Map<String, ({String url, DateTime goodUntil})> _links = {};

  /// The largest photo accepted (after the picker has shrunk it).
  static const maxBytes = 5 * 1024 * 1024;

  /// The stored value for [patientId]'s photo.
  static String storedValueFor(String patientId) => '$_prefix$patientId/photo';

  /// True when [stored] points at a private patient photo.
  static bool isPrivate(String? stored) => stored != null && stored.startsWith(_prefix);

  /// A link that shows [stored] right now, or null when there is no photo
  /// or the link can't be made (offline, or the viewer may not see it).
  Future<String?> linkFor(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    if (!isPrivate(stored)) return stored; // an ordinary public link
    final cached = _links[stored];
    if (cached != null && DateTime.now().isBefore(cached.goodUntil)) return cached.url;
    try {
      final url = await _supabase.storage
          .from(bucket)
          .createSignedUrl(stored.substring(_prefix.length), _linkLife.inSeconds);
      _links[stored] = (url: url, goodUntil: DateTime.now().add(_linkLife - const Duration(minutes: 10)));
      return url;
    } catch (e) {
      debugPrint('PatientPhotoService.linkFor failed: $e');
      return null;
    }
  }

  /// Saves [bytes] as [patientId]'s photo and records it on her account.
  /// Returns null when it worked, or what went wrong in her words.
  Future<String?> save(String patientId, Uint8List bytes, {String contentType = 'image/jpeg'}) async {
    if (bytes.length > maxBytes) return 'That photo is too large. Choose one under 5 MB.';
    final stored = storedValueFor(patientId);
    try {
      await _supabase.storage.from(bucket).uploadBinary(
            stored.substring(_prefix.length),
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      final rows = await _supabase
          .from('users')
          .update({'photo_url': stored})
          .eq('id', patientId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw StateError('the server accepted the request but changed nothing');
      }
      _links.remove(stored); // the old link shows the old photo
      return null;
    } catch (e) {
      debugPrint('PatientPhotoService.save failed: $e');
      return "We couldn't save your photo. Check your connection and try again.";
    }
  }

  /// Removes [patientId]'s photo. Returns null when it worked.
  Future<String?> remove(String patientId) async {
    final stored = storedValueFor(patientId);
    try {
      final rows = await _supabase
          .from('users')
          .update({'photo_url': null})
          .eq('id', patientId)
          .select('id');
      if ((rows as List).isEmpty) {
        throw StateError('the server accepted the request but changed nothing');
      }
      _links.remove(stored);
      // The account no longer points at it, so a failure here leaves only
      // an unreachable file; the next photo replaces it.
      try {
        await _supabase.storage.from(bucket).remove([stored.substring(_prefix.length)]);
      } catch (e) {
        debugPrint('PatientPhotoService.remove: file left behind: $e');
      }
      return null;
    } catch (e) {
      debugPrint('PatientPhotoService.remove failed: $e');
      return "We couldn't remove your photo. Check your connection and try again.";
    }
  }
}
