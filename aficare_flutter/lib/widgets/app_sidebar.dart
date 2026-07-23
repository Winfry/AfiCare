import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class SidebarItem {
  final IconData icon;
  final String label;
  final String route;
  final String? group;

  const SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.group,
  });
}

class AppSidebar extends StatelessWidget {
  final List<SidebarItem> items;
  final String currentRoute;
  final String role;
  final bool isDark;

  const AppSidebar({
    super.key,
    required this.items,
    required this.currentRoute,
    required this.role,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AfiCareTheme.darkSurface : AfiCareTheme.white;
    final textColor = isDark ? AfiCareTheme.darkTextPrimary : AfiCareTheme.ink;
    final subtextColor = isDark ? AfiCareTheme.darkTextSecondary : AfiCareTheme.slate;
    final activeColor = isDark ? const Color(0xFF64B5F6) : AfiCareTheme.canopy;
    final hoverColor = isDark
        ? const Color(0xFF1E3A5F).withOpacity( 0.5)
        : AfiCareTheme.mist;
    final borderColor = isDark ? AfiCareTheme.darkBorder : AfiCareTheme.line;

    final groups = <String, List<SidebarItem>>{};
    for (final item in items) {
      final group = item.group ?? '';
      groups.putIfAbsent(group, () => []).add(item);
    }

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AfiCare',
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'MEDILINK',
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: subtextColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Items grouped
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: groups.entries.expand((entry) {
                final widgets = <Widget>[];
                if (entry.key.isNotEmpty) {
                  widgets.add(Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: GoogleFonts.ibmPlexMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: subtextColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ));
                }
                for (final item in entry.value) {
                  final isActive = currentRoute == item.route;
                  widgets.add(Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: isActive ? activeColor.withOpacity( 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.go(item.route),
                        hoverColor: hoverColor,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: isActive ? activeColor : subtextColor,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: GoogleFonts.ibmPlexSans(
                                    fontSize: 13,
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                    color: isActive ? activeColor : textColor,
                                  ),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  width: 3,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ));
                }
                return widgets;
              }).toList(),
            ),
          ),

          // Bottom section
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: activeColor.withOpacity( 0.1),
                  child: Text(
                    role.isNotEmpty ? role[0].toUpperCase() : 'U',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    role,
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
