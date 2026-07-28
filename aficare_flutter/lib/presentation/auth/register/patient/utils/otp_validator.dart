class OtpValidator {
  OtpValidator._();

  /// Returns true if [code] is exactly 6 numeric digits.
  static bool isValid(String code) {
    return code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code);
  }

  /// Validates an OTP code and returns an error message, or null if valid.
  static String? validate(String code) {
    if (code.isEmpty) return 'Enter the verification code';
    if (code.length != 6) return 'Code must be 6 digits';
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return 'Code must contain only numbers';
    return null;
  }
}
