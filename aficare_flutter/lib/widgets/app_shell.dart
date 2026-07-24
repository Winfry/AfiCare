import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_breakpoints.dart';

sealed class SidebarEntry {}

class SidebarGroupLabel extends SidebarEntry {
  SidebarGroupLabel(this.label);
  final String label;
}

class SidebarNavItem extends SidebarEntry {
  SidebarNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class BottomNavItem {
  const BottomNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.sidebarEntries,
    required this.bottomNavItems,
    required this.selectedIndex,
    required this.body,
    required this.searchHint,
    required this.avatarLabel,
    this.onSelect,
    this.onBottomNavSelect,
    this.avatarColor,
    this.showNotificationDot = true,
    this.trailingActions = const [],
    this.onLogout,
  });

  final List<SidebarEntry> sidebarEntries;
  final List<BottomNavItem> bottomNavItems;

  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final ValueChanged<int>? onBottomNavSelect;

  final Widget body;
  final String searchHint;
  final String avatarLabel;
  final Color? avatarColor;
  final bool showNotificationDot;
  final List<Widget> trailingActions;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.sidebarCollapse;

        return Scaffold(
          backgroundColor: AppColors.mistBackground,
          body: Row(
            children: [
              if (isWide)
                _Sidebar(
                  entries: sidebarEntries,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  onLogout: onLogout,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      searchHint: searchHint,
                      avatarLabel: avatarLabel,
                      avatarColor: avatarColor,
                      showNotificationDot: showNotificationDot,
                      trailingActions: trailingActions,
                      isWide: isWide,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isWide ? 28 : 16,
                          isWide ? 30 : 20,
                          isWide ? 28 : 16,
                          isWide ? 60 : 90,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1300),
                            child: body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : _BottomNav(
                  items: bottomNavItems,
                  selectedIndex: selectedIndex,
                  onSelect: onBottomNavSelect,
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.entries,
    required this.selectedIndex,
    this.onSelect,
    this.onLogout,
  });

  final List<SidebarEntry> entries;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    var navIndex = -1;

    return Container(
      width: 236,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 22),
            child: _BrandMark(),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final entry in entries)
                  if (entry is SidebarGroupLabel)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                      child: Text(
                        entry.label.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .8,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  else if (entry is SidebarNavItem)
                    _SidebarTile(
                      icon: entry.icon,
                      label: entry.label,
                      selected: (++navIndex) == selectedIndex,
                      onTap: () => onSelect?.call(navIndex),
                    ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.borderSubtle)),
            ),
            padding: const EdgeInsets.only(top: 10),
            child: _SidebarTile(
              icon: Icons.logout,
              label: 'Log out',
              selected: false,
              onTap: onLogout ?? () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (selected)
                Positioned(
                  left: -14,
                  top: 8,
                  bottom: 8,
                  child: Container(width: 3, decoration: BoxDecoration(
                    color: AppColors.lightBlue,
                    borderRadius: BorderRadius.circular(2),
                  )),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: selected ? Colors.white : AppColors.textMuted),
                    const SizedBox(width: 11),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primaryNavy, AppColors.deepNavy]),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const Text('A',
              style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AfiCare', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            Text('MEDILINK',
                style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchHint,
    required this.avatarLabel,
    required this.showNotificationDot,
    required this.trailingActions,
    required this.isWide,
    this.avatarColor,
  });

  final String searchHint;
  final String avatarLabel;
  final Color? avatarColor;
  final bool showNotificationDot;
  final List<Widget> trailingActions;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.mistBackground,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 17, color: AppColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      searchHint,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          ...trailingActions,
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.mistBackground,
                  foregroundColor: AppColors.textMuted,
                ),
              ),
              if (showNotificationDot)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.emergency,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: avatarColor ?? AppColors.lightBlue,
            child: Text(
              avatarLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.deepNavy),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.selectedIndex, this.onSelect});

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    final clampedIndex = selectedIndex < items.length ? selectedIndex : 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++)
              InkWell(
                onTap: () => onSelect?.call(i),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].icon, size: 20, color: i == clampedIndex ? activeColor : AppColors.textMuted),
                      const SizedBox(height: 3),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: i == clampedIndex ? activeColor : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
