import 'package:flutter/material.dart';

import '../../../widgets/loading_button.dart';
import 'otp_digit_field.dart';
import 'resend_timer.dart';

class OtpVerificationCard extends StatefulWidget {
  const OtpVerificationCard({
    super.key,
    required this.onVerify,
    required this.onResend,
    required this.isVerifying,
    this.error,
  });

  final Future<bool> Function(String code) onVerify;
  final VoidCallback onResend;
  final bool isVerifying;
  final String? error;

  @override
  State<OtpVerificationCard> createState() => _OtpVerificationCardState();
}

class _OtpVerificationCardState extends State<OtpVerificationCard> {
  final _codeNotifier = ValueNotifier<String>('');
  bool _codeValid = false;

  @override
  void dispose() {
    _codeNotifier.dispose();
    super.dispose();
  }

  void _onCodeChanged(String code) {
    _codeNotifier.value = code;
    _codeValid = code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code);
  }

  Future<void> _verify() async {
    if (!_codeValid) return;
    await widget.onVerify(_codeNotifier.value);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 32,
            color: Color(0xFF206B5D),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF152A45),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'A 6-digit code was sent to your phone',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF55708A),
            ),
          ),
          const SizedBox(height: 24),
          OtpDigitField(
            onChanged: _onCodeChanged,
            onCompleted: () {},
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ValueListenableBuilder<String>(
              valueListenable: _codeNotifier,
              builder: (context, code, _) {
                final valid = code.length == 6 && RegExp(r'^\d{6}$').hasMatch(code);
                return LoadingButton(
                  label: 'Verify',
                  loading: widget.isVerifying,
                  onPressed: valid ? _verify : null,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          ResendTimer(onResend: widget.onResend),
        ],
      ),
    );
  }
}
