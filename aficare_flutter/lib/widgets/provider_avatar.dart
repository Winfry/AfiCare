import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/avatar_storage.dart';
import '../utils/avatar_registry.dart';
import '../utils/default_avatars.dart';

/// Reusable avatar widget for healthcare providers.
///
/// Resolution order:
///   1. [photoUrl] — network image from Supabase Storage
///   2. Patient's saved avatar choice — from [AvatarStorage]
///   3. Default illustration — based on [role] + [gender]
///   4. Initials fallback — if no illustration available
///
/// When [patientId] and [providerId] are both provided, the widget
/// automatically checks for a saved avatar choice.
///
/// When [onChooseAvatar] is provided, a small edit icon appears on
/// hover/tap allowing the patient to pick a new avatar.
///
/// Usage:
/// ```dart
/// ProviderAvatar(
///   name: 'Dr. Jane Smith',
///   role: UserRole.doctor,
///   gender: 'female',
///   photoUrl: user.photoUrl,
///   patientId: currentUserId,
///   providerId: provider.id,
///   radius: 24,
///   onChooseAvatar: () => showAvatarPicker(...),
/// )
/// ```
class ProviderAvatar extends StatefulWidget {
  const ProviderAvatar({
    super.key,
    required this.name,
    this.role = UserRole.doctor,
    this.gender,
    this.photoUrl,
    this.patientId,
    this.providerId,
    this.radius = 24,
    this.showBorder = false,
    this.borderColor,
    this.onChooseAvatar,
  });

  final String name;
  final UserRole role;
  final String? gender;
  final String? photoUrl;
  final String? patientId;
  final String? providerId;
  final double radius;
  final bool showBorder;
  final Color? borderColor;

  /// When non-null, a small "choose" icon appears allowing the patient
  /// to pick an avatar from the gallery.
  final VoidCallback? onChooseAvatar;

  @override
  State<ProviderAvatar> createState() => _ProviderAvatarState();
}

class _ProviderAvatarState extends State<ProviderAvatar> {
  String? _savedAvatar;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void didUpdateWidget(ProviderAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patientId != widget.patientId ||
        oldWidget.providerId != widget.providerId) {
      _loadSaved();
    }
  }

  Future<void> _loadSaved() async {
    if (widget.patientId == null || widget.providerId == null) {
      if (mounted) setState(() => _loaded = true);
      return;
    }
    final saved = await AvatarStorage.get(
      patientId: widget.patientId!,
      providerId: widget.providerId!,
    );
    if (mounted) {
      setState(() {
        _savedAvatar = saved;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        widget.photoUrl != null && widget.photoUrl!.isNotEmpty;
    final hasSaved = _loaded && _savedAvatar != null;
    final canChoose = widget.onChooseAvatar != null && !hasPhoto;

    // Determine the image provider
    ImageProvider? image;
    if (hasPhoto) {
      image = NetworkImage(widget.photoUrl!);
    } else if (hasSaved && AvatarRegistry.isAvatar(_savedAvatar)) {
      image = AssetImage(_savedAvatar!);
    } else if (_loaded) {
      // Try default illustration
      final asset =
          DefaultAvatar.assetPath(role: widget.role, gender: widget.gender);
      image = AssetImage(asset);
    }

    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: DefaultAvatar.backgroundColor(widget.role),
      backgroundImage: image,
      child: image == null ? _initialsChild : null,
    );

    if (!canChoose) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: widget.onChooseAvatar,
            child: Container(
              width: widget.radius * 0.65,
              height: widget.radius * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFF1D3557),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit,
                size: widget.radius * 0.35,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget get _initialsChild {
    final text = DefaultAvatar.initials(widget.name);
    final fg = DefaultAvatar.foregroundColor(widget.role);
    return Text(
      text,
      style: TextStyle(
        fontSize: widget.radius * 0.7,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
  }
}

/// Compact avatar for list rows.
class ProviderAvatarSmall extends StatelessWidget {
  const ProviderAvatarSmall({
    super.key,
    required this.name,
    this.role = UserRole.doctor,
    this.gender,
    this.photoUrl,
    this.patientId,
    this.providerId,
    this.radius = 16,
    this.onChooseAvatar,
  });

  final String name;
  final UserRole role;
  final String? gender;
  final String? photoUrl;
  final String? patientId;
  final String? providerId;
  final double radius;
  final VoidCallback? onChooseAvatar;

  @override
  Widget build(BuildContext context) {
    return ProviderAvatar(
      name: name,
      role: role,
      gender: gender,
      photoUrl: photoUrl,
      patientId: patientId,
      providerId: providerId,
      radius: radius,
      onChooseAvatar: onChooseAvatar,
    );
  }
}
