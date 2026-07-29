import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class BrandPanel extends StatelessWidget {
  const BrandPanel({
    super.key,
    required this.title,
    required this.headline,
    required this.subtitle,
    this.child,
    this.photoUrl,
  });

  final String title;
  final String headline;
  final String subtitle;
  final Widget? child;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final bool usePhoto = photoUrl != null;

    final Widget content = Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoRow(title: title),
          const Spacer(),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 32,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xffC7D2DC),
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (!usePhoto) ...[
            const SizedBox(height: 40),
            if (child != null) child!,
          ],
        ],
      ),
    );

    if (usePhoto) {
      return Stack(
        children: [
          SizedBox.expand(
            child: Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x591D3557), // primaryNavy @ 35%
                    Color(0x8C1D3557), // primaryNavy @ 55%
                    Color(0xEB152A45), // deepNavy @ 92%
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          content,
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PLACEHOLDER PHOTO',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryNavy,
            AppColors.navyGradientMid,
            AppColors.deepNavy,
          ],
        ),
      ),
      child: content,
    );
  }
}

class _LogoRow extends StatelessWidget {
  const _LogoRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            "A",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
