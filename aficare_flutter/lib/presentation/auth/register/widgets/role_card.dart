import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import 'role_model.dart';

class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.role,
    required this.onTap,
  });

  final RegisterRole role;
  final VoidCallback onTap;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered ? Colors.transparent : const Color(0xFFDCE3EA),
            width: 1,
          ),
          boxShadow: [
            if (_hovered)
              const BoxShadow(
                color: Color(0x1A152A45),
                blurRadius: 20,
                offset: Offset(0, 8),
              )
            else
              const BoxShadow(
                color: Color(0x0F152A45),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.role.iconCircleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.role.icon,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: widget.role.titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.role.description,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.45,
                            color: Color(0xFF55708A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted.withOpacity(0.6),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
