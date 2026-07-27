import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'brand_panel.dart';

class AuthSplitLayout extends StatelessWidget {
  const AuthSplitLayout({
    super.key,
    required this.child,
    this.showBrandPanel = true,
    this.brandTitle = 'AfiCare MediLink',
    this.brandHeadline = "One ID. Every facility you've ever visited.",
    this.brandSubtitle =
        'Secure. Connected. Available whenever you need your healthcare records.',
  });

  final Widget child;

  final bool showBrandPanel;

  final String brandTitle;
  final String brandHeadline;
  final String brandSubtitle;

  static const desktopBreakpoint = 860.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= desktopBreakpoint;

            if (!isDesktop) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: child,
                  ),
                ),
              );
            }

            return Row(
              children: [
                if (showBrandPanel)
                  Expanded(
                    flex: 5,
                    child: BrandPanel(
                      title: brandTitle,
                      headline: brandHeadline,
                      subtitle: brandSubtitle,
                    ),
                  ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 32,
                      ),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 420),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
