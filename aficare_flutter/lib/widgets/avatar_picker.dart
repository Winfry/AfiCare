import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/avatar_registry.dart';
import '../services/avatar_storage.dart';

/// Bottom-sheet grid picker for choosing a provider avatar.
///
/// Shows all available avatars from [AvatarRegistry] in a 3-column grid.
/// Tapping an avatar saves the choice via [AvatarStorage] and pops
/// with the selected asset path.
///
/// ```dart
/// final chosen = await showAvatarPicker(
///   context: context,
///   patientId: 'abc-123',
///   providerId: 'dr-smith',
/// );
/// if (chosen != null) setState(() {});
/// ```
Future<String?> showAvatarPicker({
  required BuildContext context,
  required String patientId,
  required String providerId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AvatarPickerSheet(
      patientId: patientId,
      providerId: providerId,
    ),
  );
}

class _AvatarPickerSheet extends StatefulWidget {
  const _AvatarPickerSheet({
    required this.patientId,
    required this.providerId,
  });
  final String patientId;
  final String providerId;

  @override
  State<_AvatarPickerSheet> createState() => _AvatarPickerSheetState();
}

class _AvatarPickerSheetState extends State<_AvatarPickerSheet> {
  String? _selected;

  static const _ink = Color(0xFF152A45);
  static const _slate = Color(0xFF55708A);

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final current = await AvatarStorage.get(
      patientId: widget.patientId,
      providerId: widget.providerId,
    );
    if (mounted) setState(() => _selected = current);
  }

  Future<void> _pick(String asset) async {
    await AvatarStorage.set(
      patientId: widget.patientId,
      providerId: widget.providerId,
      assetPath: asset,
    );
    if (mounted) {
      setState(() => _selected = asset);
      Navigator.pop(context, asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose an avatar',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F3F5),
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.close, size: 16, color: _slate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pick an avatar to represent this provider',
                  style: TextStyle(fontSize: 13.5, color: _slate),
                ),
              ),
              const SizedBox(height: 16),

              // Avatar grid
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: AvatarRegistry.all.length,
                  itemBuilder: (context, index) {
                    final asset = AvatarRegistry.all[index];
                    final isSelected = _selected == asset;
                    return _AvatarTile(
                      asset: asset,
                      isSelected: isSelected,
                      onTap: () => _pick(asset),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AvatarTile extends StatefulWidget {
  const _AvatarTile({
    required this.asset,
    required this.isSelected,
    required this.onTap,
  });
  final String asset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_AvatarTile> createState() => _AvatarTileState();
}

class _AvatarTileState extends State<_AvatarTile> {
  bool _hovered = false;

  static const _navy = Color(0xFF1D3557);
  static const _line = Color(0xFFDCE3EA);

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected ? _navy : _line,
              width: widget.isSelected ? 2.5 : 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _navy.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  widget.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFE8EDF3),
                    child: const Icon(Icons.person,
                        size: 32, color: Color(0xFF55708A)),
                  ),
                ),
                // Checkmark overlay
                if (widget.isSelected)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: _navy,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
