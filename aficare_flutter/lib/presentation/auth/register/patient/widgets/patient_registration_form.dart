import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../widgets/branded_text_field.dart';
import '../../../../../providers/auth_provider.dart';
import '../../../widgets/inline_error.dart';
import '../../../widgets/loading_button.dart';
import '../utils/phone_formatter.dart';
import 'otp_verification_card.dart';
import 'patient_success_animation.dart';
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

  String _formattedPhone = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final formatted = PhoneFormatter.format(_phoneController.text);
    if (formatted == null) {
      setState(() => _error = 'Please enter a valid Kenyan phone number (e.g. 0712345678)');
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

    setState(() {
      _sendingOtp = false;
      if (success) {
        _otpVisible = true;
      } else {
        _error = auth.error ?? 'Failed to send verification code. Try again.';
      }
    });
  }

  Future<bool> _verifyOtp(String code) async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyPatientOtp(
      phone: _formattedPhone,
      otp: code,
    );

    if (!mounted) return false;

    if (success) {
      setState(() => _showSuccess = true);
      return true;
    } else {
      setState(() {
        _verifying = false;
        _error = auth.error ?? 'Incorrect verification code. Try again.';
      });
      return false;
    }
  }

  void _onSuccessComplete() {
    if (!mounted) return;
    context.go('/patient');
  }

  void _onResend() {
    _sendOtp();
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
          BrandedTextField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'John Doe',
            icon: Icons.person_outline,
            validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 20),
          BrandedTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '0712345678',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your phone number';
              if (!PhoneFormatter.isValid(v)) return 'Enter a valid Kenyan phone number';
              return null;
            },
          ),
          const SizedBox(height: 24),
          LoadingButton(
            label: 'Send verification code',
            loading: _sendingOtp,
            onPressed: _sendOtp,
          ),
          const TermsText(),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _otpVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: OtpVerificationCard(
                      onVerify: _verifyOtp,
                      onResend: _onResend,
                      isVerifying: _verifying,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
