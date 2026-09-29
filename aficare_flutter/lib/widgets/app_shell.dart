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

/// Per-role restyling for [AppShell]. Every field is nullable and falls
/// back to the shell's original look, so a role that passes no theme
/// (provider, facility admin) renders exactly as it did before this was
/// introduced. Added for the patient redesign, which needs a different
/// rail, top bar and page ground without dragging the other roles along.
class AppShellTheme {
  const AppShellTheme({
    this.pageBackground,
    this.contentMaxWidth,
    this.collapseWidth,
    this.railWidth,
    this.railDecoration,
    this.railPadding,
    this.railActiveColor,
    this.railItemColor,
    this.railItemRadius,
    this.railItemStyle,
    this.railGroupStyle,
    this.topBarHeight,
    this.topBarBottomBorder,
    this.searchFill,
    this.searchRadius,
    this.searchMaxWidth,
    this.bottomNavActiveColor,
  });

  final Color? pageBackground;
  final double? contentMaxWidth;
  final double? collapseWidth;

  final double? railWidth;
  final Decoration? railDecoration;
  final EdgeInsetsGeometry? railPadding;
  final Color? railActiveColor;
  final Color? railItemColor;
  final double? railItemRadius;
  final TextStyle? railItemStyle;
  final TextStyle? railGroupStyle;

  final double? topBarHeight;
  final BorderSide? topBarBottomBorder;
  final Color? searchFill;
  final double? searchRadius;
  final double? searchMaxWidth;

  final Color? bottomNavActiveColor;
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
    this.avatarPhotoUrl,
    this.shellTheme,
    this.brandMark,
    this.sidebarFooter,
    this.onAvatarTap,
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

  /// When set, the top-bar account badge shows this photo instead of
  /// [avatarLabel]'s initials -- e.g. a provider's own uploaded photo
  /// (030_provider_photos.sql). Optional/nullable so every shell that
  /// doesn't pass it keeps today's exact initials-badge behavior.
  final String? avatarPhotoUrl;

  /// Optional per-role restyling; see [AppShellTheme].
  final AppShellTheme? shellTheme;

  /// Replaces the default "AfiCare / MEDILINK" rail header when given.
  final Widget? brandMark;

  /// Replaces the rail's default log-out tile when given (the patient
  /// shell puts an account/profile-switcher button here instead).
  final Widget? sidebarFooter;

  /// Makes the top-bar account badge tappable (patient: opens the
  /// profile switcher).
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final t = shellTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= (t?.collapseWidth ?? AppBreakpoints.sidebarCollapse);

        return Scaffold(
          backgroundColor:
              t?.pageBackground ?? (isDark ? AppColors.darkScaffold : AppColors.mistBackground),
          body: Row(
            children: [
              if (isWide)
                _Sidebar(
                  entries: sidebarEntries,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                  onLogout: onLogout,
                  isDark: isDark,
                  theme: t,
                  brandMark: brandMark,
                  footer: sidebarFooter,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      searchHint: searchHint,
                      avatarLabel: avatarLabel,
                      avatarColor: avatarColor,
                      avatarPhotoUrl: avatarPhotoUrl,
                      showNotificationDot: showNotificationDot,
                      trailingActions: trailingActions,
                      isWide: isWide,
                      isDark: isDark,
                      onSearch: onSearch,
                      onNotificationTap: onNotificationTap,
                      onAvatarTap: onAvatarTap,
                      theme: t,
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
                            constraints: BoxConstraints(maxWidth: t?.contentMaxWidth ?? 1300),
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
                  activeColor: t?.bottomNavActiveColor,
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
    this.theme,
    this.brandMark,
    this.footer,
  });

  final List<SidebarEntry> entries;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final VoidCallback? onLogout;
  final bool isDark;
  final AppShellTheme? theme;
  final Widget? brandMark;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // The sidebar is always the dark-navy brand rail regardless of `isDark`
    // (which only affects the main content area) -- matches the target
    // workspace design's permanent dark sidebar, not a togglable dark mode.
    const borderColor = Colors.white24;
    const groupLabelColor = Color(0xFF8AA0BC);

    return Container(
      width: theme?.railWidth ?? 236,
      decoration: theme?.railDecoration ??
          const BoxDecoration(
            color: AppColors.deepNavy,
            border: Border(right: BorderSide(color: borderColor)),
          ),
      padding: theme?.railPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 22),
            child: brandMark ?? const _BrandMark(),
          ),
          Expanded(
            child: ListView(
              children: _buildNavTiles(theme?.railGroupStyle == null ? groupLabelColor : null),
            ),
          ),
          if (footer != null)
            footer!
          else
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
                theme: theme,
              ),
            ),
        ],
      ),
    );
  }
  List<Widget> _buildNavTiles(Color? groupLabelColor) {
    final tiles = <Widget>[];
    var navIndex = -1;
    for (final entry in entries) {
      if (entry is SidebarGroupLabel) {
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Text(
            entry.label.toUpperCase(),
            style: theme?.railGroupStyle ??
                TextStyle(
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
          theme: theme,
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
    this.theme,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppShellTheme? theme;

  // Always the light-on-navy palette -- the sidebar itself is permanently
  // dark, not a light/dark togglable surface (see _Sidebar.build).
  static const _activeColor = AppColors.adminColor; // accent purple: only
  // this stands out against the navy sidebar bg -- the previous navy
  // active-pill relied on contrast with a WHITE sidebar and would vanish
  // here.
  static const _mutedColor = Color(0xFFD6DFEA);

  @override
  Widget build(BuildContext context) {
    final radius = theme?.railItemRadius ?? 8;
    final muted = theme?.railItemColor ?? _mutedColor;
    final active = theme?.railActiveColor ?? _activeColor;
    final baseStyle = theme?.railItemStyle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? active : Colors.transparent,
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? Colors.white : muted),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (baseStyle ?? const TextStyle(fontSize: 14)).copyWith(
                      fontWeight: selected
                          ? FontWeight.w600
                          : (baseStyle?.fontWeight ?? FontWeight.w500),
                      color: selected ? Colors.white : muted,
                    ),
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
    this.avatarPhotoUrl,
    this.isDark = false,
    this.onSearch,
    this.onNotificationTap,
    this.onAvatarTap,
    this.theme,
  });

  final String searchHint;
  final String avatarLabel;
  final Color? avatarColor;
  final String? avatarPhotoUrl;
  final bool showNotificationDot;
  final List<Widget> trailingActions;
  final bool isWide;
  final bool isDark;
  final VoidCallback? onSearch;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final AppShellTheme? theme;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white.withOpacity(.08) : AppColors.borderSubtle;
    final chipBg = theme?.searchFill ?? (isDark ? Colors.white.withOpacity(.07) : AppColors.mistBackground);
    final mutedColor = isDark ? const Color(0xFFC7D2DC) : AppColors.textMuted;
    final searchRadius = theme?.searchRadius ?? 999;

    return Container(
      height: theme?.topBarHeight ?? 66,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkAppBar : Colors.white,
        border: Border(bottom: theme?.topBarBottomBorder ?? BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (isWide)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: theme?.searchMaxWidth ?? 420),
              child: _searchChip(chipBg, mutedColor, searchRadius),
            )
          else
            Expanded(child: _searchChip(chipBg, mutedColor, searchRadius)),
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
          _Avatar(
            label: avatarLabel,
            color: avatarColor,
            photoUrl: avatarPhotoUrl,
            onTap: onAvatarTap,
          ),
        ],
      ),
    );
  }

  Widget _searchChip(Color bg, Color muted, double radius) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSearch,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: theme == null
              ? null
              : BoxDecoration(
                  border: Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(radius),
                ),
          child: Row(
            children: [
              Icon(Icons.search, size: 17, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchHint,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.label, this.color, this.photoUrl, this.onTap});

  final String label;
  final Color? color;
  final String? photoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final avatar = CircleAvatar(
      radius: 18,
      backgroundColor: color ?? AppColors.lightBlue,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.deepNavy),
            ),
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: avatar,
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.items,
    required this.selectedIndex,
    this.onSelect,
    this.activeColor,
  });

  final List<BottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int>? onSelect;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = this.activeColor ?? Theme.of(context).colorScheme.primary;
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
