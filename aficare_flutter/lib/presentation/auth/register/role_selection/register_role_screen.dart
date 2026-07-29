import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/auth_footer.dart';
import '../../widgets/auth_form_container.dart';
import '../../widgets/auth_split_layout.dart';
import '../widgets/role_grid.dart';
import '../widgets/role_model.dart';

class RegisterRoleScreen extends StatelessWidget {
  const RegisterRoleScreen({super.key});

  List<RegisterRole> get roles => const [
        RegisterRole(
          title: "I'm a patient",
          description: "Get your MediLink ID and access records from any facility.",
          icon: Icons.person_rounded,
          iconCircleColor: Color(0xFF1D3557),
          titleColor: Color(0xFF1D3557),
          route: "/register/patient",
        ),
        RegisterRole(
          title: "I'm a doctor",
          description: "Manage patients, write prescriptions, and send referrals.",
          icon: Icons.medical_services_rounded,
          iconCircleColor: Color(0xFF38B2AC),
          titleColor: Color(0xFF38B2AC),
          route: "/register/doctor",
        ),
        RegisterRole(
          title: "I'm a nurse",
          description: "Track patient vitals, administer care, and coordinate teams.",
          icon: Icons.health_and_safety_rounded,
          iconCircleColor: Color(0xFF4A90E2),
          titleColor: Color(0xFF4A90E2),
          route: "/register/nurse",
        ),
        RegisterRole(
          title: "I'm a radiologist",
          description: "Review imaging orders, upload reports, and share results.",
          icon: Icons.biotech_rounded,
          iconCircleColor: Color(0xFF457B9D),
          titleColor: Color(0xFF457B9D),
          route: "/register/radiologist",
        ),
        RegisterRole(
          title: "I'm an admin",
          description: "Manage facilities, users, system settings, and analytics.",
          icon: Icons.admin_panel_settings_rounded,
          iconCircleColor: Color(0xFF6D597A),
          titleColor: Color(0xFF6D597A),
          route: "/register/admin",
          fullWidth: true,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      brandHeadline: 'Secure. Private. Always you.',
      brandSubtitle: 'Your health, your data, your control.',
      brandPhotoUrl: 'assets/images/RegisterRole.jpg',
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'I want to register as',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFamily: 'Fraunces',
                color: Color(0xFF152A45),
              ),
            ),
            const SizedBox(height: 20),
            RoleGrid(roles: roles),
            const SizedBox(height: 20),
            AuthFooter(
              question: "Already have an account? ",
              action: "Log In",
              onTap: () => context.go("/login"),
            ),
          ],
        ),
      ),
    );
  }
}
