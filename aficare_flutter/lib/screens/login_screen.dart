import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aficare_flutter/theme/app_colors.dart';
import 'package:aficare_flutter/widgets/segmented_toggle.dart';
import 'package:aficare_flutter/widgets/branded_text_field.dart';
import 'package:aficare_flutter/widgets/referral_path_preview.dart';

enum _LoginMethod { email, medilinkId }

/// Route: `/login`
///
/// Desktop/web (>= [_wideBreakpoint]): two-pane split — brand story on the
/// left, form on the right, each taking real width instead of a form
/// floating alone in a wide page.
///
/// Mobile (< [_wideBreakpoint]): the brand pane collapses away entirely and
/// the form becomes the whole screen, with a compact logo at the top.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _wideBreakpoint = 860.0;

  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  _LoginMethod _method = _LoginMethod.email;
  bool _keepSignedIn = false;
  bool _submitting = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      // TODO: wire this up to the real auth service, e.g.:
      // final result = await context.read<AuthService>().login(
      //   identifier: _identifierController.text,
      //   password: _passwordController.text,
      //   method: _method,
      // );
      // then route based on result.role (patient / provider / admin).
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      context.go('/patient');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;

            if (isWide) {
              return Row(
                children: [
                  const Expanded(flex: 5, child: _BrandPanel()),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                        child: _LoginForm(
                          showLogo: false,
                          formKey: _formKey,
                          method: _method,
                          onMethodChanged: (m) => setState(() => _method = m),
                          identifierController: _identifierController,
                          passwordController: _passwordController,
                          keepSignedIn: _keepSignedIn,
                          onKeepSignedInChanged: (v) => setState(() => _keepSignedIn = v ?? false),
                          submitting: _submitting,
                          onSubmit: _submit,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: _LoginForm(
                  showLogo: true,
                  formKey: _formKey,
                  method: _method,
                  onMethodChanged: (m) => setState(() => _method = m),
                  identifierController: _identifierController,
                  passwordController: _passwordController,
                  keepSignedIn: _keepSignedIn,
                  onKeepSignedInChanged: (v) => setState(() => _keepSignedIn = v ?? false),
                  submitting: _submitting,
                  onSubmit: _submit,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryNavy, AppColors.deepNavy],
        ),
      ),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white.withOpacity(.2)),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: AppColors.lightBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AfiCare MediLink',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('HEALTH RECORDS, LINKED',
                      style: TextStyle(color: Color(0xFF9AAFC0), fontSize: 10, letterSpacing: 1.4)),
                ],
              ),
            ],
          ),
          const Spacer(),
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "One ID. Every facility\nyou've ever visited.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Log in to see your prescriptions, referrals, and lab results — wherever they were issued.',
                  style: TextStyle(color: Color(0xFFC7D2DC), fontSize: 15, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          const ReferralPathPreview(),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withOpacity(.18))),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"I didn\'t have to repeat my blood test at the referral hospital."',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Wanjiru M. — Kiambu County',
                  style: TextStyle(color: AppColors.lightBlue, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.showLogo,
    required this.formKey,
    required this.method,
    required this.onMethodChanged,
    required this.identifierController,
    required this.passwordController,
    required this.keepSignedIn,
    required this.onKeepSignedInChanged,
    required this.submitting,
    required this.onSubmit,
  });

  final bool showLogo;
  final GlobalKey<FormState> formKey;
  final _LoginMethod method;
  final ValueChanged<_LoginMethod> onMethodChanged;
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool keepSignedIn;
  final ValueChanged<bool?> onKeepSignedInChanged;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isEmail = method == _LoginMethod.email;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLogo) ...[
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryNavy, AppColors.deepNavy],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('A',
                        style: TextStyle(
                            color: AppColors.lightBlue, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AfiCare', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('MEDILINK',
                          style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log in to continue to your dashboard',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),

            SegmentedToggle<_LoginMethod>(
              values: const [_LoginMethod.email, _LoginMethod.medilinkId],
              labels: const ['Email', 'MediLink ID'],
              selected: method,
              onChanged: onMethodChanged,
            ),
            const SizedBox(height: 20),

            BrandedTextField(
              controller: identifierController,
              label: isEmail ? 'Email address' : 'MediLink ID',
              hint: isEmail ? 'wanjiru@example.com' : 'MDL-KE-2291-7740',
              icon: isEmail ? Icons.mail_outline : Icons.badge_outlined,
              keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isEmail ? 'Enter your email address' : 'Enter your MediLink ID';
                }
                if (isEmail && !value.contains('@')) return 'Enter a valid email address';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            BrandedTextField(
              controller: passwordController,
              label: 'Password',
              hint: '••••••••',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) =>
                  (value == null || value.isEmpty) ? 'Enter your password' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: Checkbox(
                        value: keepSignedIn,
                        onChanged: onKeepSignedInChanged,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Keep me signed in',
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                  child: const Text('Forgot password?', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Log in'),
            ),
            const SizedBox(height: 20),

            Center(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                  children: [
                    const TextSpan(text: "Don't have an account? "),
                    TextSpan(
                      text: 'Register',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
                      recognizer: TapGestureRecognizer()..onTap = () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F1F5),
                border: Border.all(color: const Color(0xFFC9DCE8)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '◈ Demo accounts\n',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2C4A63)),
                    ),
                    TextSpan(
                      text:
                          'patient@demo.aficare.ke · provider@demo.aficare.ke · admin@demo.aficare.ke — password: demo1234',
                      style: TextStyle(color: Color(0xFF2C4A63)),
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
