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
    this.brandPhotoUrl,
  });

  final Widget child;

  final bool showBrandPanel;

  final String brandTitle;
  final String brandHeadline;
  final String brandSubtitle;
  final String? brandPhotoUrl;

  static const desktopBreakpoint = 860.0;

  ImageProvider<Object> _resolveImage(String path) =>
      (path.startsWith('http') ? NetworkImage(path) : AssetImage(path)) as ImageProvider<Object>;

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
              final bool usePhoto =
                  brandPhotoUrl != null && showBrandPanel;

              final Widget formContent = Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: usePhoto
                        ? Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            color: Colors.white,
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: child,
                            ),
                          )
                        : child,
                  ),
                ),
              );

              if (usePhoto) {
                return Stack(
                  children: [
                    SizedBox.expand(
                      child: Image(
                        image: _resolveImage(brandPhotoUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x591D3557),
                              Color(0x8C1D3557),
                              Color(0xEB152A45),
                            ],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    formContent,
                  ],
                );
              }

              return formContent;
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
                      photoUrl: brandPhotoUrl,
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
