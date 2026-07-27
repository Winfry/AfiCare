import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:aficare_flutter/theme/app_colors.dart';
import 'package:aficare_flutter/widgets/segmented_toggle.dart';
import 'package:aficare_flutter/widgets/branded_text_field.dart';
import 'package:aficare_flutter/widgets/referral_path_preview.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/models/user_model.dart';

enum _LoginMethod { email, medilinkId }

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
  String? _errorMsg;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _routeForRole(UserRole role) {
    switch (role) {
      case UserRole.patient:
      case UserRole.radiologist:
        return '/patient';
      case UserRole.doctor:
      case UserRole.nurse:
        return '/provider';
      case UserRole.admin:
        return '/admin';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _submitting = true; _errorMsg = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    if (_method == _LoginMethod.medilinkId) {
      success = await auth.signInWithMedilinkId(
        medilinkId: _identifierController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      success = await auth.signIn(
        email: _identifierController.text.trim(),
        password: _passwordController.text,
      );
    }

    if (!mounted) return;

    if (success && auth.currentUser != null) {
      final route = _routeForRole(auth.currentUser!.role);
      context.go(route);
    } else {
      setState(() {
        _errorMsg = auth.error ?? 'Login failed. Please check your credentials.';
        _submitting = false;
      });
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
                        child: _buildForm(showLogo: false),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(child: _buildForm(showLogo: true)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildForm({required bool showLogo}) {
    final isEmail = _method == _LoginMethod.email;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLogo) ...[
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primaryNavy, AppColors.deepNavy]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('A', style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AfiCare', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('MEDILINK', style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],

            const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy)),
            const SizedBox(height: 6),
            const Text('Log in to continue to your dashboard', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 24),

            SegmentedToggle<_LoginMethod>(
              values: const [_LoginMethod.email, _LoginMethod.medilinkId],
              labels: const ['Email', 'MediLink ID'],
              selected: _method,
              onChanged: (m) => setState(() { _method = m; _errorMsg = null; }),
            ),
            const SizedBox(height: 20),

            BrandedTextField(
              controller: _identifierController,
              label: isEmail ? 'Email address' : 'MediLink ID',
              hint: isEmail ? 'wanjiru@example.com' : 'ML-NBO-XXXX',
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
              controller: _passwordController,
              label: 'Password',
              hint: '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022',
              icon: Icons.lock_outline,
              isPassword: true,
              validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),

            if (_errorMsg != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.clay.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.clay.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: AppColors.clay),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!, style: const TextStyle(fontSize: 13, color: AppColors.clay))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 20, height: 20,
                      child: Checkbox(
                        value: _keepSignedIn,
                        onChanged: (v) => setState(() => _keepSignedIn = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Keep me signed in', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
                      recognizer: TapGestureRecognizer()..onTap = () => context.go('/register'),
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
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: '\u25C8 Demo accounts\n',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2C4A63)),
                    ),
                    const TextSpan(
                      text: 'patient@demo.aficare.ke \u00B7 provider@demo.aficare.ke \u00B7 admin@demo.aficare.ke\n',
                      style: TextStyle(color: Color(0xFF2C4A63)),
                    ),
                    const TextSpan(
                      text: 'Password: demo1234',
                      style: TextStyle(color: Color(0xFF2C4A63)),
                    ),
                  ],
                ),
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ),
          ],
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
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: Colors.white.withOpacity(.2)),
                ),
                alignment: Alignment.center,
                child: const Text('A', style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700, fontSize: 18)),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AfiCare MediLink', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  Text('HEALTH RECORDS, LINKED', style: TextStyle(color: Color(0xFF9AAFC0), fontSize: 10, letterSpacing: 1.4)),
                ],
              ),
            ],
          ),
          const Spacer(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "One ID. Every facility\nyou've ever visited.",
                  style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Log in to see your prescriptions, referrals, and lab results \u2014 wherever they were issued.',
                  style: TextStyle(color: Color(0xFFC7D2DC), fontSize: 15, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          ReferralPathPreview(),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.only(top: 20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(.18)))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"I didn\'t have to repeat my blood test at the referral hospital."',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontStyle: FontStyle.italic, height: 1.4),
                ),
                SizedBox(height: 8),
                Text(
                  'Wanjiru M. \u2014 Kiambu County',
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
