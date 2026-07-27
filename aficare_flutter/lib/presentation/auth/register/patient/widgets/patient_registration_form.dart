import 'package:flutter/material.dart';

import '../../../../../widgets/branded_text_field.dart';
import '../../../widgets/inline_error.dart';
import '../../../widgets/loading_button.dart';

class PatientRegistrationForm extends StatefulWidget {
  const PatientRegistrationForm({super.key});

  @override
  State<PatientRegistrationForm> createState() =>
      _PatientRegistrationFormState();
}

class _PatientRegistrationFormState extends State<PatientRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  bool _loading = false;
  bool _otpVisible = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _loading = false;
      _otpVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          InlineError(message: _error),
          BrandedTextField(
            controller: _name,
            label: 'Full Name',
            hint: 'Enter your full name',
            icon: Icons.person_outline,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 20),
          BrandedTextField(
            controller: _phone,
            label: 'Phone Number',
            hint: '+254712345678',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          LoadingButton(
            label: 'Send verification code',
            loading: _loading,
            onPressed: _sendOtp,
          ),
          const SizedBox(height: 16),
          const Text(
            'By continuing you agree to our Terms & Privacy Policy.',
            textAlign: TextAlign.center,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            child: _otpVisible
                ? const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text(
                      'OTP verification card will be plugged in during Phase 3B.',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
