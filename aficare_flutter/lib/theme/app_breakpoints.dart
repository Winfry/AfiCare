/// Shared responsive breakpoints. Reference these everywhere instead of
/// hardcoding widths, so every screen's desktop/mobile switch happens at
/// the same points.
class AppBreakpoints {
  AppBreakpoints._();

  /// Below this width, the login screen drops its split brand panel.
  static const double loginSplit = 860;

  /// Below this width, the app shell (patient/provider/admin) collapses
  /// its sidebar into a bottom navigation bar.
  static const double sidebarCollapse = 940;
}
