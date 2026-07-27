import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../theme/app_colors.dart';
import '../../widgets/auth_footer.dart';
import '../../widgets/auth_form_container.dart';
import '../../widgets/auth_page_header.dart';
import '../../widgets/auth_split_layout.dart';
import '../widgets/role_grid.dart';
import '../widgets/role_model.dart';

class RegisterRoleScreen extends StatelessWidget {
  const RegisterRoleScreen({super.key});

  List<RegisterRole> get roles => const [
        RegisterRole(
          title: "I'm a Patient",
          description:
              "Get your MediLink ID and access records from any facility.",
          icon: Icons.person_rounded,
          color: AppColors.primaryNavy,
          route: "/register/patient",
        ),
        RegisterRole(
          title: "I'm a Doctor",
          description:
              "Manage patients, write prescriptions and send referrals.",
          icon: Icons.medical_services_rounded,
          color: AppColors.canopy,
          route: "/register/doctor",
        ),
        RegisterRole(
          title: "I'm a Nurse",
          description:
              "Track patient vitals, administer care and coordinate teams.",
          icon: Icons.health_and_safety_rounded,
          color: AppColors.steelBlue,
          route: "/register/nurse",
        ),
        RegisterRole(
          title: "I'm a Radiologist",
          description:
              "Review imaging orders, upload reports and share results.",
          icon: Icons.biotech_rounded,
          color: Color(0xFF457B9D),
          route: "/register/radiologist",
        ),
        RegisterRole(
          title: "I'm an Admin",
          description:
              "Manage facilities, users, analytics and system settings.",
          icon: Icons.admin_panel_settings_rounded,
          color: Color(0xFF6D597A),
          route: "/register/admin",
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return AuthSplitLayout(
      brandHeadline: "Choose how you'll use AfiCare.",
      brandSubtitle:
          "Every role gets a tailored registration experience built around the way you work.",
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeader(
              title: "Choose your role",
              subtitle:
                  "Select the option that best describes how you'll use AfiCare.",
              onBack: () => context.pop(),
            ),
            RoleGrid(roles: roles),
            const SizedBox(height: 32),
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
