import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../../providers/auth_provider.dart';
import '../../../widgets/inline_error.dart';
import '../../../widgets/loading_button.dart';
import '../utils/phone_formatter.dart';
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

  bool _loading = false;
  bool _showSuccess = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final formatted = PhoneFormatter.format('254${_phoneController.text}');
    if (formatted == null) {
      setState(() => _error = 'Please enter a valid Kenyan phone number');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUpPatientDirect(
      phone: formatted,
      fullName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccess = true);
    } else {
      setState(() {
        _loading = false;
        _error = auth.error ?? 'Failed to create account. Try again.';
      });
    }
  }

  void _onSuccessComplete() {
    if (!mounted) return;
    context.go('/onboarding');
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
            label: 'Create account',
            loading: _loading,
            onPressed: _createAccount,
          ),
          const TermsText(),
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
