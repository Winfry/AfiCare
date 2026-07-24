import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({super.key, required this.child, this.isDark = false});

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(.08) : AppColors.borderSubtle),
      ),
      child: child,
    );
  }
}
