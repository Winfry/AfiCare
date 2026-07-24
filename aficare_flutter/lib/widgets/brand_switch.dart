import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class BrandSwitch extends StatelessWidget {
  const BrandSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.mutedColor = AppColors.textMuted,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: mutedColor)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 22,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.primaryNavy : AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
