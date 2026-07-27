import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AuthPageHeader extends StatelessWidget {
  const AuthPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null)
          IconButton(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),

        const SizedBox(height: 8),

        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textMuted,
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}
