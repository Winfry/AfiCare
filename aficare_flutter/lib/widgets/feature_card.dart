import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'tier_badge.dart';

class FeatureCard extends StatefulWidget {
  const FeatureCard({
    super.key,
    required this.badgeLabel,
    required this.title,
    required this.description,
    required this.linkLabel,
    required this.onTap,
  });

  final String badgeLabel;
  final String title;
  final String description;
  final String linkLabel;
  final VoidCallback onTap;

  @override
  State<FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<FeatureCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
        padding: const EdgeInsets.fromLTRB(26, 30, 26, 26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hovering ? Colors.transparent : AppColors.borderSubtle),
          boxShadow: _hovering
              ? [
                  BoxShadow(
                    color: AppColors.deepNavy.withOpacity(.14),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TierBadge(label: widget.badgeLabel, style: TierBadgeStyle.accent, size: 30),
                const SizedBox(height: 18),
                Text(widget.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.deepNavy)),
                const SizedBox(height: 10),
                Text(
                  widget.description,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.55),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.linkLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryNavy),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
