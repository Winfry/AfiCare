import 'package:flutter/material.dart';
import 'package:aficare_flutter/utils/theme.dart';
import 'package:aficare_flutter/widgets/app_sidebar.dart';
import 'package:aficare_flutter/widgets/app_topbar.dart';
import 'package:aficare_flutter/widgets/bottom_nav.dart';

class AppShell extends StatelessWidget {
  final List<SidebarItem> sidebarItems;
  final List<BottomNavItem> bottomNavItems;
  final int currentBottomIndex;
  final ValueChanged<int> onBottomNavTap;
  final String currentRoute;
  final String role;
  final Widget child;
  final bool showDarkToggle;
  final bool isDark;
  final VoidCallback? onDarkToggle;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const AppShell({
    super.key,
    required this.sidebarItems,
    required this.bottomNavItems,
    required this.currentBottomIndex,
    required this.onBottomNavTap,
    required this.currentRoute,
    required this.role,
    required this.child,
    this.showDarkToggle = false,
    this.isDark = false,
    this.onDarkToggle,
    this.notificationCount = 0,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 940;
    final scaffoldBg = isDark ? AfiCareTheme.darkShell : AfiCareTheme.mist;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: isWide
          ? Row(
              children: [
                AppSidebar(
                  items: sidebarItems,
                  currentRoute: currentRoute,
                  role: role,
                  isDark: isDark,
                ),
                Expanded(
                  child: Column(
                    children: [
                      AppTopbar(
                        title: '',
                        showDarkToggle: showDarkToggle,
                        isDark: isDark,
                        onDarkToggle: onDarkToggle,
                        notificationCount: notificationCount,
                        onNotificationTap: onNotificationTap,
                        avatarLabel: role.isNotEmpty ? role[0] : null,
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(child: child),
                AppBottomNav(
                  items: bottomNavItems,
                  currentIndex: currentBottomIndex,
                  onTap: onBottomNavTap,
                ),
              ],
            ),
    );
  }
}
