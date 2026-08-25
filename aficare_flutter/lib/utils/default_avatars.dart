import 'package:flutter/material.dart';

import '../models/user_model.dart';

/// Default avatar illustrations for healthcare providers.
///
/// When a provider has no uploaded profile photo and the patient hasn't
/// picked a custom avatar, the system shows one of these based on role+gender.
class DefaultAvatar {
  const DefaultAvatar._();

  // ── Asset paths ────────────────────────────────────────────────

  static const _base = 'assets/images';

  static const doctorMale   = '$_base/doc-male-01.png';
  static const doctorFemale = '$_base/doc-female-01.png';
  static const nurseMale    = '$_base/nurse-male-01.png';
  static const nurseFemale  = '$_base/nurse-female-01.png';
  static const generic      = '$_base/Avatar.png';

  // ── Role → color mapping (for initials fallback) ──────────────

  static const _roleColors = {
    UserRole.doctor:     Color(0xFF1D3557),
    UserRole.nurse:      Color(0xFF2E7D32),
    UserRole.radiologist: Color(0xFF457B9D),
    UserRole.admin:      Color(0xFF55708A),
    UserRole.patient:    Color(0xFF1D3557),
  };

  static const _roleLabels = {
    UserRole.doctor:     'Dr',
    UserRole.nurse:      'N',
    UserRole.radiologist: 'R',
    UserRole.admin:      'A',
    UserRole.patient:    'P',
  };

  // ── Public API ────────────────────────────────────────────────

  /// Returns the default asset path for a given role + gender.
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
