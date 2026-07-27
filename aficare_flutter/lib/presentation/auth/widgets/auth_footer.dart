import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class AuthFooter extends StatelessWidget {
  const AuthFooter({
    super.key,
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
          ),
          children: [
            TextSpan(text: question),

            TextSpan(
              text: action,
              style: const TextStyle(
                color: AppColors.canopy,
                fontWeight: FontWeight.w700,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = onTap,
            ),
          ],
        ),
      ),
    );
  }
}
