import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.clayBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.clay.withOpacity(.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.clay,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.clay,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
