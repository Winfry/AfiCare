import 'package:flutter/material.dart';

/// A tappable chip displayed in the dashboard header that shows the currently
/// active profile (own or a dependent) and triggers the profile-switcher sheet.
class ProfileSwitcherChip extends StatelessWidget {
  final String currentName;
  final String? currentMedilinkId;
  final bool isViewingDependent;
  final VoidCallback onSwitchRequested;

  const ProfileSwitcherChip({
    super.key,
    required this.currentName,
    this.currentMedilinkId,
    this.isViewingDependent = false,
    required this.onSwitchRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Switch profile. Currently viewing: $currentName',
      child: InkWell(
        onTap: onSwitchRequested,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isViewingDependent ? 0.3 : 0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(isViewingDependent ? 0.6 : 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isViewingDependent ? Icons.child_care : Icons.person,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (currentMedilinkId != null)
                      Text(
                        'ID: $currentMedilinkId',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.85),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
