import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../utils/default_avatars.dart';

/// Reusable avatar widget for healthcare providers.
///
/// Resolution order:
///   1. [photoUrl] — network image from Supabase Storage
///   2. Default illustration — based on [role] + [gender]
///   3. Initials fallback — if illustration asset doesn't exist yet
///
/// Usage:
/// ```dart
/// ProviderAvatar(
///   name: 'Dr. Jane Smith',
///   role: UserRole.doctor,
///   gender: 'female',
///   photoUrl: user.photoUrl,
///   radius: 24,
/// )
/// ```
class ProviderAvatar extends StatelessWidget {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.role = UserRole.doctor,
    this.gender,
    this.photoUrl,
    this.radius = 24,
    this.showBorder = false,
    this.borderColor,
  });

  final String name;
  final UserRole role;
  final String? gender;
  final String? photoUrl;
  final double radius;
  final bool showBorder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: DefaultAvatar.backgroundColor(role),
      backgroundImage: _backgroundImage,
      child: _backgroundImage == null ? _initialsChild : null,
    );
  }

  ImageProvider? get _backgroundImage {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return NetworkImage(photoUrl!);
    }
    // Try default illustration — will fail gracefully if asset missing
    final asset = DefaultAvatar.assetPath(role: role, gender: gender);
    return AssetImage(asset);
  }

  Widget get _initialsChild {
    final text = DefaultAvatar.initials(name);
    final fg = DefaultAvatar.foregroundColor(role);
    return Text(
      text,
      style: TextStyle(
        fontSize: radius * 0.7,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
  }
}

/// Compact avatar for list rows — smaller, no border.
class ProviderAvatarSmall extends StatelessWidget {
  const ProviderAvatarSmall({
    super.key,
    required this.name,
    this.role = UserRole.doctor,
    this.gender,
    this.photoUrl,
    this.radius = 16,
  });

  final String name;
  final UserRole role;
  final String? gender;
  final String? photoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ProviderAvatar(
      name: name,
      role: role,
      gender: gender,
      photoUrl: photoUrl,
      radius: radius,
    );
  }
}
