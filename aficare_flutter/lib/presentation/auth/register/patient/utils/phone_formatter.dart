class PhoneFormatter {
  PhoneFormatter._();

  /// Formats a Kenyan phone number to E.164 format (+254XXXXXXXXX).
  ///
  /// Accepts:
  ///   - 0712345678
  ///   - 0112345678
  ///   - 712345678
  ///   - 254712345678
  ///   - +254712345678
  ///
  /// Returns +254712345678 or null if the number is invalid.
  static String? format(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[\s\-\(\)\.]'), '');

    // Already in E.164 format
    if (cleaned.startsWith('+254')) {
      return cleaned.length == 13 ? cleaned : null;
    }

    // 254 prefix without +
    if (cleaned.startsWith('254')) {
      final number = '+$cleaned';
      return number.length == 13 ? number : null;
    }

    // 07XX or 01XX (10 digits)
    if (cleaned.startsWith('0') && cleaned.length == 10) {
      return '+254${cleaned.substring(1)}';
    }

    // 7XX (9 digits, no prefix)
    if (cleaned.length == 9) {
      return '+254$cleaned';
    }

    return null;
  }

  /// Returns true if the raw input is a plausible Kenyan number.
  static bool isValid(String raw) => format(raw) != null;
}
