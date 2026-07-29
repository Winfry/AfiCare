import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/user_model.dart';
import '../../widgets/auth_split_layout.dart';
import '../../widgets/auth_form_container.dart';
import '../../widgets/auth_page_header.dart';
import '../../widgets/inline_error.dart';
import '../../../../widgets/branded_text_field.dart';
import '../../widgets/loading_button.dart';
import '../../../../providers/auth_provider.dart';
import '../widgets/password_strength_indicator.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _orgController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  static const _adminColor = Color(0xFF6D597A);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _orgController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      role: UserRole.admin,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      context.go('/admin');
    } else {
      setState(() {
        _error = auth.error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      brandHeadline: 'Set up your organization account.',
      brandSubtitle: 'Manage facilities, staff, and system-wide settings from one place.',
      brandPhotoUrl: 'assets/images/AdminRegisterScreen.webp',
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeader(
              title: 'Create admin account',
              subtitle: 'Set up your organization account.',
              onBack: () => context.pop(),
            ),
            InlineError(message: _error),
            _buildForm(),
            const SizedBox(height: 24),
            LoadingButton(
              label: 'Create account',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => context.go('/login'),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13.5, color: Color(0xFF55708A)),
                    children: [
                      const TextSpan(text: "Already have an account? "),
                      TextSpan(
                        text: 'Log in',
                        style: const TextStyle(color: _adminColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        BrandedTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Amina Diallo',
          icon: Icons.person_outline,
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name' : null,
        ),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'you@organization.ke',
          icon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email address';
            if (!v.contains('@')) return 'Enter a valid email address';
            return null;
          },
        ),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _phoneController,
          label: 'Phone Number (optional)',
          hint: '712 345 678',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _orgController,
          label: 'Organization / Facility',
          hint: 'e.g. Nairobi West Health Network',
          icon: Icons.business_rounded,
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter your organization name' : null,
        ),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _passwordController,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter a password';
            if (v.length < 8) return 'Password must be at least 8 characters';
            return null;
          },
        ),
        PasswordStrengthIndicator(password: _passwordController.text),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _confirmController,
          label: 'Confirm Password',
          hint: '••••••••',
          icon: Icons.lock_outline,
          isPassword: true,
          validator: (v) => v != _passwordController.text ? 'Passwords do not match' : null,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: true,
                onChanged: (_) {},
                activeColor: _adminColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF55708A), height: 1.5),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms',
                      style: TextStyle(color: Color(0xFF206B5D), fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: ' & '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(color: Color(0xFF206B5D), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
