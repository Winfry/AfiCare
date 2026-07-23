import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _useMedilinkId = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success;
    if (_useMedilinkId) {
      success = await authProvider.signInWithMedilinkId(
        medilinkId: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      success = await authProvider.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      final role = authProvider.currentUser?.role.name ?? 'patient';
      const roleRoutes = {
        'patient': '/patient',
        'doctor': '/provider',
        'nurse': '/provider',
        'admin': '/admin',
      };
      context.go(roleRoutes[role] ?? '/patient');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Login failed'),
          backgroundColor: AfiCareTheme.clay,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isWide = MediaQuery.of(context).size.width > 860;

    return Scaffold(
      backgroundColor: AfiCareTheme.paper,
      body: isWide ? _buildWideLayout(authProvider) : _buildNarrowLayout(authProvider),
    );
  }

  Widget _buildWideLayout(AuthProvider authProvider) {
    return Row(
      children: [
        // Left branding panel
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AfiCareTheme.canopy, AfiCareTheme.canopy2],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity( 0.15),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AfiCare',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'MEDILINK',
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity( 0.7),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Heading
                  Text(
                    'Your health records,\nyour control.',
                    style: GoogleFonts.fraunces(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Access your complete medical history from any provider in Kenya. Secure, portable, and always yours.',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 15,
                      color: Colors.white.withOpacity( 0.8),
                      height: 1.6,
                    ),
                  ),

                  const Spacer(),

                  // Quote
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity( 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '"AfiCare changed how I manage my diabetes. Every lab result, every prescription — all in one place." — Mary N.',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        color: Colors.white.withOpacity( 0.9),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right form panel
        Expanded(
          child: _buildFormPanel(authProvider, showMobileLogo: false),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(AuthProvider authProvider) {
    return _buildFormPanel(authProvider, showMobileLogo: true);
  }

  Widget _buildFormPanel(AuthProvider authProvider, {required bool showMobileLogo}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mobile logo
                if (showMobileLogo) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AfiCareTheme.canopy,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: GoogleFonts.fraunces(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AfiCare',
                        style: GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AfiCareTheme.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],

                // Heading
                Text(
                  'Welcome back',
                  style: GoogleFonts.fraunces(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: AfiCareTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to continue to AfiCare MediLink',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 14,
                    color: AfiCareTheme.slate,
                  ),
                ),

                const SizedBox(height: 28),

                // Segmented toggle
                Container(
                  decoration: BoxDecoration(
                    color: AfiCareTheme.mist,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _useMedilinkId = false;
                            _emailController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_useMedilinkId ? AfiCareTheme.canopy : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Email',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: !_useMedilinkId ? Colors.white : AfiCareTheme.slate,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _useMedilinkId = true;
                            _emailController.clear();
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _useMedilinkId ? AfiCareTheme.canopy : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'MediLink ID',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _useMedilinkId ? Colors.white : AfiCareTheme.slate,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Email/ID field
                TextFormField(
                  controller: _emailController,
                  keyboardType: _useMedilinkId ? TextInputType.text : TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: GoogleFonts.ibmPlexSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _useMedilinkId ? 'ML-NBO-XXXXXX' : 'your@email.com',
                    prefixIcon: Icon(
                      _useMedilinkId ? Icons.badge_outlined : Icons.email_outlined,
                      size: 18,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return _useMedilinkId ? 'Please enter your MediLink ID' : 'Please enter your email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: GoogleFonts.ibmPlexSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Remember me + forgot
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: Checkbox(
                            value: false,
                            onChanged: (_) {},
                            activeColor: AfiCareTheme.canopy,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Remember me',
                          style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AfiCareTheme.slate),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: Text(
                        'Forgot password?',
                        style: GoogleFonts.ibmPlexSans(fontSize: 13, color: AfiCareTheme.canopy),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _login,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Log in'),
                  ),
                ),

                const SizedBox(height: 16),

                // Register link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: GoogleFonts.ibmPlexSans(fontSize: 14, color: AfiCareTheme.slate),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text(
                        'Register',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AfiCareTheme.canopy,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Demo box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AfiCareTheme.marigold.withOpacity( 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AfiCareTheme.marigold.withOpacity( 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo Accounts',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7A5A1E),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Patient: patient@demo.com / demo123',
                        style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AfiCareTheme.ink),
                      ),
                      Text(
                        'Doctor: doctor@demo.com / demo123',
                        style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AfiCareTheme.ink),
                      ),
                      Text(
                        'Admin: admin@demo.com / demo123',
                        style: GoogleFonts.ibmPlexMono(fontSize: 12, color: AfiCareTheme.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
