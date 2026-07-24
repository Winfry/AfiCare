import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.iconBackground,
    this.iconColor,
    this.deltaLabel,
    this.deltaBackground,
    this.deltaColor,
    this.hero = false,
    this.isDark = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? iconBackground;
  final Color? iconColor;
  final String? deltaLabel;
  final Color? deltaBackground;
  final Color? deltaColor;
  final bool hero;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final onHeroText = Colors.white;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(.08) : AppColors.borderSubtle;
    final labelColor = hero
        ? onHeroText.withOpacity(.75)
        : (isDark ? const Color(0xFF93A0AB) : AppColors.textMuted);
    final valueColor = hero ? onHeroText : (isDark ? Colors.white : AppColors.deepNavy);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: hero
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryNavy, AppColors.navyGradientMid],
              )
            : null,
        color: hero ? null : surfaceColor,
        border: hero ? null : Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hero ? Colors.white.withOpacity(.15) : (iconBackground ?? AppColors.tintNavyBg),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: hero ? Colors.white : (iconColor ?? AppColors.primaryNavy)),
              ),
              if (deltaLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: hero ? Colors.white.withOpacity(.18) : (deltaBackground ?? AppColors.tintSuccessBg),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    deltaLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: hero ? Colors.white : (deltaColor ?? AppColors.nonUrgent),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: valueColor)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: labelColor)),
        ],
      ),
    );
  }
}
