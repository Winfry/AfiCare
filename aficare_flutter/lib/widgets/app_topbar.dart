import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class AppTopbar extends StatelessWidget {
  final String title;
  final bool showDarkToggle;
  final bool isDark;
  final VoidCallback? onDarkToggle;
  final int notificationCount;
  final VoidCallback? onNotificationTap;
  final String? avatarLabel;

  const AppTopbar({
    super.key,
    required this.title,
    this.showDarkToggle = false,
    this.isDark = false,
    this.onDarkToggle,
    this.notificationCount = 0,
    this.onNotificationTap,
    this.avatarLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AfiCareTheme.darkSurface : AfiCareTheme.white;
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final subtextColor = isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate;
    final borderColor = isDark ? AfiCareTheme.darkBorder : AfiCareTheme.line;
    final activeColor = isDark ? const Color(0xFF64B5F6) : AfiCareTheme.canopy;

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? AfiCareTheme.darkShell.withOpacity( 0.5)
                    : AfiCareTheme.mist,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search patients, records...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: GoogleFonts.ibmPlexSans(
                          fontSize: 13.5,
                          color: subtextColor,
                        ),
                      ),
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13.5,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 18),

          // Dark mode toggle
          if (showDarkToggle) ...[
            GestureDetector(
              onTap: onDarkToggle,
              child: Container(
                width: 44,
                height: 24,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF64B5F6) : AfiCareTheme.line,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      size: 12,
                      color: isDark ? const Color(0xFF162D4A) : AfiCareTheme.slate,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],

          // Notifications
          GestureDetector(
            onTap: onNotificationTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: subtextColor,
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AfiCareTheme.clay,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$notificationCount',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: activeColor.withOpacity( 0.1),
            child: Text(
              avatarLabel ?? 'U',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: activeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
