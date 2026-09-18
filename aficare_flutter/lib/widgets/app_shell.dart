import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_breakpoints.dart';

sealed class SidebarEntry {
  const SidebarEntry();
}

class SidebarGroupLabel extends SidebarEntry {
  const SidebarGroupLabel(this.label);
  final String label;
}

class SidebarNavItem extends SidebarEntry {
  const SidebarNavItem({required this.icon, required this.label});
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
    this.isDark = false,
    this.onSearch,
    this.onNotificationTap,
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
  final VoidCallback? onSearch;
  final bool isDark;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AppBreakpoints.sidebarCollapse;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkScaffold : AppColors.mistBackground,
          body: Row(
            children: [
              if (isWide)
                _Sidebar(
                  entries: sidebarEntries,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  onLogout: onLogout,
                  isDark: isDark,
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
                      isDark: isDark,
                      onSearch: onSearch,
                      onNotificationTap: onNotificationTap,
                    ),
                    Expanded(
                      child: Padding(
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
    this.isDark = false,
  });

  final List<SidebarEntry> entries;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onLogout;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // The sidebar is always the dark-navy brand rail regardless of `isDark`
    // (which only affects the main content area) -- matches the target
    // workspace design's permanent dark sidebar, not a togglable dark mode.
    const borderColor = Colors.white24;
    const groupLabelColor = Color(0xFF8AA0BC);

    return Container(
      width: 236,
      decoration: const BoxDecoration(
        color: AppColors.deepNavy,
        border: Border(right: BorderSide(color: borderColor)),
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
              children: _buildNavTiles(groupLabelColor),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
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
  List<Widget> _buildNavTiles(Color groupLabelColor) {
    final tiles = <Widget>[];
    var navIndex = -1;
    for (final entry in entries) {
      if (entry is SidebarGroupLabel) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            entry.label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .8,
              color: groupLabelColor,
            ),
          ),
        ));
      } else if (entry is SidebarNavItem) {
        final idx = ++navIndex;
        tiles.add(_SidebarTile(
          icon: entry.icon,
          label: entry.label,
          selected: idx == selectedIndex,
          onTap: () => onSelect?.call(idx),
        ));
      }
    }
    return tiles;
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

  // Always the light-on-navy palette -- the sidebar itself is permanently
  // dark, not a light/dark togglable surface (see _Sidebar.build).
  static const _activeColor = AppColors.adminColor; // accent purple: only
  // this stands out against the navy sidebar bg -- the previous navy
  // active-pill relied on contrast with a WHITE sidebar and would vanish
  // here.
  static const _mutedColor = Color(0xFFD6DFEA);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : _mutedColor),
                const SizedBox(width: 11),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? Colors.white : _mutedColor,
                  ),
                ),
              ],
            ),
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
            // Solid accent purple, not a navy gradient -- against the
            // sidebar's own navy background a navy-on-navy mark would
            // vanish (see _SidebarTile for the same reasoning).
            color: AppColors.adminColor,
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: const Text('A',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
        const SizedBox(width: 10),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AfiCare', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: Colors.white)),
            Text('MEDILINK',
                style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, color: Color(0xFFA9B8CC), fontWeight: FontWeight.w500)),
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
    this.isDark = false,
    this.onSearch,
    this.onNotificationTap,
  });

  final String searchHint;
  final String avatarLabel;
  final Color? avatarColor;
  final bool showNotificationDot;
  final List<Widget> trailingActions;
  final bool isWide;
  final bool isDark;
  final VoidCallback? onSearch;
  final VoidCallback? onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white.withOpacity(.08) : AppColors.borderSubtle;
    final chipBg = isDark ? Colors.white.withOpacity(.07) : AppColors.mistBackground;
    final mutedColor = isDark ? const Color(0xFFC7D2DC) : AppColors.textMuted;

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkAppBar : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (isWide)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Material(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSearch,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 17, color: mutedColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            searchHint,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: mutedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Material(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onSearch,
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 17, color: mutedColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            searchHint,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, color: mutedColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 16),
          ...trailingActions,
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onNotificationTap ?? () {},
                icon: const Icon(Icons.notifications_none_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: chipBg,
                  foregroundColor: mutedColor,
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
                      border: Border.all(color: isDark ? AppColors.darkAppBar : Colors.white, width: 1.5),
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
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onSelect?.call(i),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].icon, size: 20, color: i == clampedIndex ? activeColor : AppColors.textMuted),
                        const SizedBox(height: 3),
                        Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
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
              ),
          ],
        ),
      ),
    );
  }
}
