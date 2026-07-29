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

class ClinicianRegisterScreen extends StatefulWidget {
  const ClinicianRegisterScreen({super.key, required this.initialRole});

  final String initialRole;

  @override
  State<ClinicianRegisterScreen> createState() => _ClinicianRegisterScreenState();
}

class _ClinicianRegisterScreenState extends State<ClinicianRegisterScreen> {
  late String _role;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _departmentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  final List<String> _facilities = [
    'Select your facility',
    'Kenyatta National Hospital',
    'Aga Khan University Hospital',
    'Moi Teaching & Referral Hospital',
  ];
  String _selectedFacility = 'Select your facility';

  Color get _roleColor {
    switch (_role) {
      case 'nurse': return const Color(0xFF4A90E2);
      case 'radiologist': return const Color(0xFF457B9D);
      default: return const Color(0xFF38B2AC); // doctor
    }
  }

  String get _roleTitle {
    switch (_role) {
      case 'nurse': return "I'm a Nurse";
      case 'radiologist': return "I'm a Radiologist";
      default: return "I'm a Doctor";
    }
  }

  String get _departmentLabel {
    if (_role == 'radiologist') return 'Specialty';
    return 'Department / Specialty';
  }

  String get _departmentHint {
    switch (_role) {
      case 'nurse': return 'e.g. Outpatient, ICU';
      case 'radiologist': return 'e.g. Diagnostic Imaging';
      default: return 'e.g. Cardiology';
    }
  }

  UserRole get _userRole {
    switch (_role) {
      case 'nurse': return UserRole.nurse;
      case 'radiologist': return UserRole.radiologist;
      default: return UserRole.doctor;
    }
  }

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
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
    if (_selectedFacility == 'Select your facility') {
      setState(() => _error = 'Please select your facility');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
      role: _userRole,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      context.go('/provider');
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
      brandHeadline: 'Join AfiCare as a healthcare professional.',
      brandSubtitle: 'Manage patients, coordinate referrals, and keep every record connected across facilities.',
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeader(
              title: 'Create your account',
              subtitle: 'Join AfiCare as a healthcare professional.',
              onBack: () => context.pop(),
            ),
            _buildRoleSwitcher(),
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
                        style: TextStyle(color: _roleColor, fontWeight: FontWeight.w600),
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

  Widget _buildRoleSwitcher() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          _roleTab('doctor', 'Doctor'),
          const SizedBox(width: 8),
          _roleTab('nurse', 'Nurse'),
          const SizedBox(width: 8),
          _roleTab('radiologist', 'Radiologist'),
        ],
      ),
    );
  }

  Widget _roleTab(String role, String label) {
    final active = _role == role;
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? _roleColor : const Color(0xFFDCE3EA),
            width: active ? 1.5 : 1.5,
          ),
          color: active ? _roleColor.withOpacity(0.08) : Colors.white,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _role = role),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: active ? _roleColor : const Color(0xFF55708A),
                ),
              ),
            ),
          ),
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
          hint: 'Dr. Otieno Odhiambo',
          icon: Icons.person_outline,
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter your full name' : null,
        ),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _emailController,
          label: 'Email Address',
          hint: 'you@facility.ke',
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
        _buildFacilityField(),
        const SizedBox(height: 16),
        BrandedTextField(
          controller: _departmentController,
          label: _departmentLabel,
          hint: _departmentHint,
          icon: Icons.medical_services_outlined,
          validator: (v) => v == null || v.trim().isEmpty ? 'Enter your department/specialty' : null,
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
                activeColor: _roleColor,
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

  Widget _buildFacilityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Facility',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF55708A)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE3EA), width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFacility,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              items: _facilities.map((f) => DropdownMenuItem(
                value: f,
                child: Text(f, style: TextStyle(
                  fontSize: 14,
                  color: f == 'Select your facility' ? const Color(0xFF94A3B8) : const Color(0xFF152A45),
                )),
              )).toList(),
              onChanged: (v) => setState(() => _selectedFacility = v ?? _selectedFacility),
            ),
          ),
        ),
        TextButton(
          onPressed: () => context.go('/register-facility'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
          child: const Text(
            '+ Register new facility',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF206B5D)),
          ),
        ),
      ],
    );
  }
}
