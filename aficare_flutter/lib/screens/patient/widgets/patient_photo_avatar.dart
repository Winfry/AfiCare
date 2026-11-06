import 'package:flutter/material.dart';

import '../../../services/patient_photo_service.dart';
import '../../../theme/patient_tokens.dart';
import '../../../utils/default_avatars.dart';

/// A patient's round photo, or her initials when there is none, it can't
/// be fetched, or the viewer may not see it. Her photo is private, so the
/// stored value is turned into a short-lived link first.
class PatientPhotoAvatar extends StatefulWidget {
  const PatientPhotoAvatar({
    super.key,
    required this.name,
    required this.storedPhoto,
    this.size = 96,
  });

  final String name;

  /// `users.photo_url` as stored (a private place, or an old public link).
  final String? storedPhoto;
  final double size;

  @override
  State<PatientPhotoAvatar> createState() => _PatientPhotoAvatarState();
}

class _PatientPhotoAvatarState extends State<PatientPhotoAvatar> {
  final _photos = PatientPhotoService();
  String? _link;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(PatientPhotoAvatar old) {
    super.didUpdateWidget(old);
    if (old.storedPhoto != widget.storedPhoto) _resolve();
  }

  Future<void> _resolve() async {
    final stored = widget.storedPhoto;
    setState(() {
      _link = null;
      _broken = false;
    });
    final link = await _photos.linkFor(stored);
    // A newer photo may have arrived while this one was being fetched.
    if (mounted && stored == widget.storedPhoto) setState(() => _link = link);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final initials = Text(
      DefaultAvatar.initials(widget.name),
      style: PT.serif(fontSize: size * .36, color: PT.navy),
    );
    final showPhoto = _link != null && !_broken;
    return Semantics(
      label: showPhoto ? 'Photo of ${widget.name}' : null,
      image: showPhoto,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: PT.avatarBg),
        child: showPhoto
            ? Image.network(
                _link!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _broken = true);
                  });
                  return initials;
                },
              )
            : initials,
      ),
    );
  }
}
