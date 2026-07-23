import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class SectionHead extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final bool isDark;

  const SectionHead({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final actionColor = isDark ? const Color(0xFF64B5F6) : AfiCareTheme.canopy;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: actionColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
