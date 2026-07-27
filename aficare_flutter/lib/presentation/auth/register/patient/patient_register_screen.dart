import 'package:flutter/material.dart';

import '../../widgets/auth_split_layout.dart';
import '../../widgets/auth_form_container.dart';
import '../../widgets/auth_page_header.dart';
import 'widgets/patient_registration_form.dart';

class PatientRegisterScreen extends StatelessWidget {
  const PatientRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthSplitLayout(
      brandHeadline: 'Create your MediLink ID',
      brandSubtitle: 'Just your name and phone number.',
      child: AuthFormContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeader(
              title: 'Create your MediLink ID',
              subtitle: "Just your name and phone — that's it.",
            ),
            SizedBox(height: 12),
            PatientRegistrationForm(),
          ],
        ),
      ),
    );
  }
}
