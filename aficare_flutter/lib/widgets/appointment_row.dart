import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class AppointmentRow extends StatelessWidget {
  final String time;
  final String patientName;
  final String type;
  final String? room;
  final bool isDark;

  const AppointmentRow({
    super.key,
    required this.time,
    required this.patientName,
    required this.type,
    this.room,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final subtextColor = isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AfiCareTheme.canopy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: GoogleFonts.ibmPlexMono(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AfiCareTheme.canopy,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
          if (room != null)
            Text(
              room!,
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
