import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class BrandPanel extends StatelessWidget {
  const BrandPanel({
    super.key,
    required this.title,
    required this.headline,
    required this.subtitle,
    this.child,
  });

  final String title;
  final String headline;
  final String subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          ),
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
          const SizedBox(height: 40),
          if (child != null) child!,
        ],
      ),
    );
  }
}
