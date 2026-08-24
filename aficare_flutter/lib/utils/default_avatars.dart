import 'package:flutter/material.dart';

import '../models/user_model.dart';

/// Default avatar illustrations for healthcare providers.
///
/// When a provider has no uploaded profile photo, the system shows
/// a standardized illustration based on their role and gender.
///
/// Asset files (to be added by designer):
///   assets/images/avatar-doctor-male.png
///   assets/images/avatar-doctor-female.png
///   assets/images/avatar-nurse-male.png
///   assets/images/avatar-nurse-female.png
///   assets/images/avatar-provider.png        (generic fallback)
class DefaultAvatar {
  const DefaultAvatar._();

  // ── Asset paths ────────────────────────────────────────────────

  static const _basePath = 'assets/images';

  static const doctorMale = '$_basePath/avatar-doctor-male.png';
  static const doctorFemale = '$_basePath/avatar-doctor-female.png';
  static const nurseMale = '$_basePath/avatar-nurse-male.png';
  static const nurseFemale = '$_basePath/avatar-nurse-female.png';
  static const generic = '$_basePath/avatar-provider.png';

  // ── Role → color mapping (for initials fallback) ──────────────

  static const _roleColors = {
    UserRole.doctor: Color(0xFF1D3557),    // navy
    UserRole.nurse: Color(0xFF2E7D32),     // green
    UserRole.radiologist: Color(0xFF457B9D), // med blue
    UserRole.admin: Color(0xFF55708A),     // slate
    UserRole.patient: Color(0xFF1D3557),   // navy
  };

  static const _roleLabels = {
    UserRole.doctor: 'Dr',
    UserRole.nurse: 'N',
    UserRole.radiologist: 'R',
    UserRole.admin: 'A',
    UserRole.patient: 'P',
  };

  // ── Public API ────────────────────────────────────────────────

  /// Returns the asset path for the default avatar based on role + gender.
  ///
  /// Falls back to [generic] if role/gender are unknown.
  static String assetPath({
    required UserRole role,
    String? gender,
  }) {
    final isMale = gender?.toLowerCase() == 'male' ||
        gender?.toLowerCase() == 'm';
    final isFemale = gender?.toLowerCase() == 'female' ||
        gender?.toLowerCase() == 'f';

    switch (role) {
      case UserRole.doctor:
        if (isMale) return doctorMale;
        if (isFemale) return doctorFemale;
        return generic;
      case UserRole.nurse:
        if (isMale) return nurseMale;
        if (isFemale) return nurseFemale;
        return generic;
      default:
        return generic;
    }
  }

  /// Background color for initials fallback.
  static Color backgroundColor(UserRole role) =>
      _roleColors[role] ?? const Color(0xFFE8EDF3);

  /// Foreground color for initials text.
  static Color foregroundColor(UserRole role) {
    final bg = backgroundColor(role);
    // Dark backgrounds → white text, light backgrounds → dark text
    final luminance = bg.computeLuminance();
    return luminance < 0.4 ? Colors.white : const Color(0xFF152A45);
  }

  /// Short prefix for initials (e.g. "Dr" for doctors, "N" for nurses).
  static String rolePrefix(UserRole role) =>
      _roleLabels[role] ?? '?';

  /// Compute initials from a full name.
  static String initials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
