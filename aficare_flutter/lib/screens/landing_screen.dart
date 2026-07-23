import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aficare_flutter/utils/theme.dart';
import 'package:aficare_flutter/widgets/landing_nav.dart';
import 'package:aficare_flutter/widgets/landing_hero.dart';
import 'package:aficare_flutter/widgets/landing_features.dart';
import 'package:aficare_flutter/widgets/landing_footer.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AfiCareTheme.paper,
      body: Column(
        children: [
          LandingNav(
            onLogin: () => context.go('/login'),
            onGetStarted: () => context.go('/register'),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LandingHero(
                    onGetStarted: () => context.go('/register'),
                    onLearnMore: () {},
                  ),
                  const LandingFeatures(),
                  const LandingFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
