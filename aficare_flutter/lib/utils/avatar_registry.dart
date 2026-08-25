/// Registry of all available provider avatar illustrations.
///
/// When a provider has no uploaded photo and the patient hasn't chosen
/// an avatar yet, the patient can pick from this gallery.
///
/// To add new avatars:
///   1. Drop the PNG file in `assets/images/`
///   2. Add the path to [all] below
///   3. That's it — the picker automatically shows new entries
class AvatarRegistry {
  const AvatarRegistry._();

  static const _base = 'assets/images';

  /// All available avatar illustration asset paths.
  /// Order here = display order in the picker grid.
  static const all = [
    // Doctors
    '$_base/doc-female-01.png',
    '$_base/doc-female-02.png',
    '$_base/doc-female-03.png',
    '$_base/doc-female-04.png',
    '$_base/doc-male-01.png',
    '$_base/doc-male-02.png',
    '$_base/doc-male-03.png',
    // Nurses
    '$_base/nurse-female-01.png',
    '$_base/nurse-female-02.png',
    '$_base/nurse-female-03.png',
    '$_base/nurse-male-01.png',
    '$_base/nurse-male-02.png',
  ];

  /// Returns true if the given asset path is a known avatar.
  static bool isAvatar(String? asset) =>
      asset != null && all.contains(asset);

  /// Get avatar by index (0-based). Returns null if out of range.
  static String? byIndex(int index) =>
      index >= 0 && index < all.length ? all[index] : null;
}
