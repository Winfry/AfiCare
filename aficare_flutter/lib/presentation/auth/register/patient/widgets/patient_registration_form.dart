import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../theme/app_colors.dart';
import '../../../../../providers/auth_provider.dart';
import '../../../widgets/inline_error.dart';
import '../../../widgets/loading_button.dart';
import '../utils/phone_formatter.dart';
import 'otp_digit_field.dart';
import 'patient_success_animation.dart';
import 'phone_prefix_field.dart';
import 'terms_text.dart';

class PatientRegistrationForm extends StatefulWidget {
  const PatientRegistrationForm({super.key});

  @override
  State<PatientRegistrationForm> createState() =>
      _PatientRegistrationFormState();
}

class _PatientRegistrationFormState extends State<PatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _sendingOtp = false;
  bool _otpVisible = false;
  bool _verifying = false;
  bool _showSuccess = false;
  String? _error;
  String _otpCode = '';

  String _formattedPhone = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final formatted = PhoneFormatter.format('254${_phoneController.text}');
    if (formatted == null) {
      setState(() => _error = 'Please enter a valid Kenyan phone number');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _error = null;
      _formattedPhone = formatted;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUpPatient(
      phone: formatted,
      fullName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _sendingOtp = false;
        _otpVisible = true;
      });
    } else {
      setState(() {
        _sendingOtp = false;
        _error = auth.error ?? 'Failed to send verification code. Try again.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpCode.length != 6) return;
    setState(() {
      _verifying = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyPatientOtp(
      phone: _formattedPhone,
      otp: _otpCode,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccess = true);
    } else {
      setState(() {
        _verifying = false;
        _error = auth.error ?? 'Incorrect verification code. Try again.';
      });
    }
  }

  void _onSuccessComplete() {
    if (!mounted) return;
    context.go('/patient');
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return PatientSuccessAnimation(onComplete: _onSuccessComplete);
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          InlineError(message: _error),
          const _FieldLabel(label: 'Full Name'),
          TextFormField(
            controller: _nameController,
            style: const TextStyle(fontSize: 14.5, color: Color(0xFF152A45)),
            decoration: _inputDecoration('Wanjiru Njoroge', Icons.person_outline),
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 20),
          PhonePrefixField(
            controller: _phoneController,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your phone number';
              final formatted = PhoneFormatter.format('254$v');
              if (formatted == null) return 'Enter a valid Kenyan phone number';
              return null;
            },
          ),
          const SizedBox(height: 24),
          LoadingButton(
            label: _sendingOtp ? 'Code sent' : 'Send verification code',
            loading: _sendingOtp,
            onPressed: _sendOtp,
          ),
          const TermsText(),
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _otpVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildOtpPanel(),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.go('/login'),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13.5, color: Color(0xFF55708A)),
                  children: [
                    TextSpan(text: "Already have an account? "),
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(color: Color(0xFF206B5D), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpPanel() {
    return _OtpSlideIn(
      child: Column(
        children: [
          _buildDivider(),
          const SizedBox(height: 20),
          const Text(
            'Enter Verification Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF152A45)),
          ),
          const SizedBox(height: 20),
          OtpDigitField(
            onChanged: (code) => _otpCode = code,
            onCompleted: () {},
          ),
          const SizedBox(height: 20),
          LoadingButton(
            label: _verifying ? 'Verifying...' : 'Verify & create account',
            loading: _verifying,
            onPressed: _verifyOtp,
          ),
          const SizedBox(height: 14),
          _buildResendRow(),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFDCE3EA))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'OTP verification',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFDCE3EA))),
      ],
    );
  }

  Widget _buildResendRow() {
    return const Center(
      child: Text(
        'Resend code in 30s',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF55708A),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 19, color: const Color(0xFF55708A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF206B5D), width: 2),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF55708A)),
      ),
    );
  }
}

class _OtpSlideIn extends StatefulWidget {
  const _OtpSlideIn({required this.child});
  final Widget child;
  @override
  State<_OtpSlideIn> createState() => _OtpSlideInState();
}

class _OtpSlideInState extends State<_OtpSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 350), vsync: this);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
