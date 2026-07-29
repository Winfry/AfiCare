import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  const PasswordStrengthIndicator({
    super.key,
    required this.password,
  });

  final String password;

  int get _score {
    int s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'[0-9]').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s;
  }

  int get _level => password.isEmpty ? -1 : _score <= 1 ? 0 : _score <= 2 ? 1 : 2;

  Color _color(int index) {
    if (password.isEmpty) return const Color(0xFFDCE3EA);
    if (index > _level) return const Color(0xFFDCE3EA);
    switch (_level) {
      case 0: return AppColors.clay;
      case 1: return const Color(0xFFFFA000);
      case 2: return AppColors.sage;
      default: return const Color(0xFFDCE3EA);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) => Expanded(
            child: Container(
              height: 3,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: _color(i),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          )),
        ),
      ],
    );
  }
}
