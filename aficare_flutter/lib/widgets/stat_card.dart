import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isHero;
  final bool isDark;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor = AfiCareTheme.canopy,
    this.isHero = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isHero
        ? AfiCareTheme.canopy
        : (isDark ? AfiCareTheme.darkSurface : AfiCareTheme.white);
    final textColor = isHero
        ? Colors.white
        : (isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink);
    final subtextColor = isHero
        ? Colors.white.withOpacity( 0.8)
        : (isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate);
    final iconBg = isHero
        ? Colors.white.withOpacity( 0.15)
        : iconColor.withOpacity( 0.1);
    final borderColor = isDark ? AfiCareTheme.darkBorder : AfiCareTheme.line;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(22),
        border: isHero ? null : Border.all(color: borderColor),
        gradient: isHero
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AfiCareTheme.canopy,
                  AfiCareTheme.canopy2,
                ],
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: isHero ? Colors.white : iconColor),
              ),
              const Spacer(),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isHero
                        ? Colors.white.withOpacity( 0.15)
                        : AfiCareTheme.sage.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subtitle!,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isHero ? Colors.white : AfiCareTheme.sage,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.fraunces(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }
}
