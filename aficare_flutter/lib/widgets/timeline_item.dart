import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final Color dotColor;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const TimelineItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.time,
    this.dotColor = AfiCareTheme.canopy,
    this.isFirst = false,
    this.isLast = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final subtextColor = isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate;
    final lineColor = isDark ? AfiCareTheme.darkBorder : AfiCareTheme.line;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: dotColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
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
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
