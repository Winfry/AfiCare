import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class ActivityRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isDark;

  const ActivityRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final subtextColor = isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11.5,
              color: subtextColor,
            ),
          ),
        ],
      ),
    );
  }
}
