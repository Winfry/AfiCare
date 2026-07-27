import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ManagementCard extends StatefulWidget {
  const ManagementCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconBackground,
    required this.iconColor,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  State<ManagementCard> createState() => _ManagementCardState();
}

class _ManagementCardState extends State<ManagementCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.translationValues(0, _hovering ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovering ? Colors.transparent : AppColors.borderSubtle),
          boxShadow: _hovering
              ? [BoxShadow(color: AppColors.deepNavy.withOpacity(.14), blurRadius: 18, offset: const Offset(0, 6))]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: widget.iconBackground, borderRadius: BorderRadius.circular(10)),
                    child: Icon(widget.icon, size: 17, color: widget.iconColor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(widget.description,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5)),
                      ],
                    ),
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
