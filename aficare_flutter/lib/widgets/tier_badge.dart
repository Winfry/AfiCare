import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TierBadgeStyle { outline, filled, accent }

class TierBadge extends StatelessWidget {
  const TierBadge({
    super.key,
    this.label,
    this.icon,
    this.style = TierBadgeStyle.outline,
    this.size = 22,
    this.color,
  }) : assert(label != null || icon != null, 'Provide a label or an icon');

  final String? label;
  final IconData? icon;
  final TierBadgeStyle style;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color? border;

    if (color != null) {
      bg = color!;
      fg = Colors.white;
    } else {
      switch (style) {
        case TierBadgeStyle.outline:
          bg = Colors.white;
          fg = AppColors.primaryNavy;
          border = AppColors.primaryNavy;
        case TierBadgeStyle.filled:
          bg = AppColors.primaryNavy;
          fg = Colors.white;
        case TierBadgeStyle.accent:
          bg = AppColors.lightBlue;
          fg = AppColors.deepNavy;
      }
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: border != null ? Border.all(color: border, width: 1.5) : null,
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.55, color: fg)
          : Text(
              label!,
              style: TextStyle(
                fontSize: size * 0.42,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: fg,
              ),
            ),
    );
  }
}
