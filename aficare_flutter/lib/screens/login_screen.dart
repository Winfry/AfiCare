import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:aficare_flutter/theme/app_colors.dart';
import 'package:aficare_flutter/widgets/segmented_toggle.dart';
import 'package:aficare_flutter/widgets/branded_text_field.dart';
import 'package:aficare_flutter/providers/auth_provider.dart';
import 'package:aficare_flutter/models/user_model.dart';
import 'package:aficare_flutter/presentation/auth/widgets/auth_split_layout.dart';
import 'package:aficare_flutter/presentation/auth/widgets/inline_error.dart';
import 'package:aficare_flutter/presentation/auth/widgets/loading_button.dart';
import 'package:aficare_flutter/presentation/auth/widgets/auth_footer.dart';
import 'package:aficare_flutter/presentation/auth/register/patient/widgets/phone_prefix_field.dart';
import 'package:aficare_flutter/presentation/auth/register/patient/utils/phone_formatter.dart';

enum _LoginMethod { email, phone }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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

    if (_method == _LoginMethod.phone) {
      final formatted =
          PhoneFormatter.format('254${_identifierController.text.trim()}');
      if (formatted == null) {
        setState(() {
          _errorMsg = 'Enter a valid Kenyan phone number';
          _submitting = false;
        });
        return;
      }
      success = await auth.signInWithPhoneAndPin(
        phone: formatted,
        pin: _passwordController.text.trim(),
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
    return AuthSplitLayout(
      brandPhotoUrl: 'assets/images/LoginScreen.jpg',
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    final isEmail = _method == _LoginMethod.email;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.deepNavy)),
          const SizedBox(height: 6),
          const Text('Log in to continue to your dashboard', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 24),

          SegmentedToggle<_LoginMethod>(
            values: const [_LoginMethod.email, _LoginMethod.phone],
            labels: const ['Email', 'Phone'],
            selected: _method,
            onChanged: (m) => setState(() { _method = m; _errorMsg = null; }),
          ),
          const SizedBox(height: 20),

          if (isEmail)
            BrandedTextField(
              controller: _identifierController,
              label: 'Email address',
              hint: 'wanjiru@example.com',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your email address';
                }
                if (!value.contains('@')) return 'Enter a valid email address';
                return null;
              },
              textInputAction: TextInputAction.next,
            )
          else
            PhonePrefixField(
              controller: _identifierController,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                final formatted = PhoneFormatter.format('254$v');
                if (formatted == null) return 'Enter a valid Kenyan phone number';
                return null;
              },
            ),
          const SizedBox(height: 16),
          BrandedTextField(
            controller: _passwordController,
            label: isEmail ? 'Password' : '6-digit PIN',
            hint: isEmail ? '\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022' : '\u2022\u2022\u2022\u2022\u2022\u2022',
            icon: isEmail ? Icons.lock_outline : Icons.password_outlined,
            isPassword: true,
            keyboardType: isEmail ? null : TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return isEmail ? 'Enter your password' : 'Enter your 6-digit PIN';
              }
              if (!isEmail && (value.length != 6 || int.tryParse(value) == null)) {
                return 'PIN must be exactly 6 digits';
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),

          InlineError(message: _errorMsg),

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

          LoadingButton(
            label: 'Log in',
            loading: _submitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),

          AuthFooter(
            question: "Don't have an account? ",
            action: 'Register',
            onTap: () => context.go('/register'),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F1F5),
              border: Border.all(color: const Color(0xFFC9DCE8)),
              borderRadius: BorderRadius.circular(12),
            ),
            child:               const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '\u25C8 Demo accounts\n',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2C4A63)),
                  ),
                  TextSpan(
                    text: 'Providers / Admin: use Email tab\n',
                    style: TextStyle(color: Color(0xFF2C4A63)),
                  ),
                  TextSpan(
                    text: 'provider@demo.aficare.ke \u00B7 admin@demo.aficare.ke \u00B7 Password: demo1234\n',
                    style: TextStyle(color: Color(0xFF2C4A63)),
                  ),
                  TextSpan(
                    text: 'Patients: use Phone tab with your PIN',
                    style: TextStyle(color: Color(0xFF2C4A63)),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
