import 'package:flutter/material.dart';

class TermsText extends StatelessWidget {
  const TermsText({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF55708A),
            height: 1.4,
          ),
          children: [
            TextSpan(text: 'By continuing you agree to our '),
            TextSpan(
              text: 'Terms',
              style: TextStyle(
                color: Color(0xFF206B5D),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: ' & '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: Color(0xFF206B5D),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
