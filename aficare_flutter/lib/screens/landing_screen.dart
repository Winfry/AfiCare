import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/referral_path_preview.dart';
import '../widgets/feature_card.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  static const _wideBreakpoint = 900.0;
  static const _maxContentWidth = 1320.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _NavBar(onLogin: () => context.go('/login')),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideBreakpoint;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(isWide ? 48 : 20, 40, isWide ? 48 : 20, isWide ? 90 : 50),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(flex: 21, child: _HeroCopy(onLogin: () => context.go('/login'))),
                                const SizedBox(width: 60),
                                const Expanded(flex: 20, child: _HeroPathCard()),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _HeroCopy(onLogin: () => context.go('/login')),
                                const SizedBox(height: 36),
                                const _HeroPathCard(),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
            const _PartnersStrip(),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= _wideBreakpoint;
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: isWide ? 80 : 48),
                      child: _FeaturesSection(isWide: isWide),
                    ),
                  ),
                );
              },
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= LandingScreen._wideBreakpoint;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 20, vertical: 22),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryNavy, AppColors.navyGradientMid]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text('A', style: TextStyle(color: AppColors.lightBlue, fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AfiCare', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('MEDILINK', style: TextStyle(fontSize: 9.5, letterSpacing: 1.3, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                if (isWide) ...[
                  const _NavLink('For patients'),
                  const SizedBox(width: 30),
                  const _NavLink('For providers'),
                  const SizedBox(width: 30),
                  const _NavLink('For facilities'),
                  const SizedBox(width: 30),
                  TextButton(onPressed: onLogin, child: const Text('Log in')),
                  const SizedBox(width: 14),
                ],
                ElevatedButton(
                  onPressed: onLogin,
                  style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                  child: const Text('Get started'),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: AppColors.deepNavy));
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.onLogin});
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 16, height: 1.5, color: AppColors.lightBlue),
            const SizedBox(width: 8),
            const Text(
              'CONNECTED CARE, COUNTY TO COUNTY',
              style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: AppColors.primaryNavy),
            ),
          ],
        ),
        const SizedBox(height: 18),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.08, color: AppColors.deepNavy),
            children: [
              TextSpan(text: 'Every referral, every record, '),
              TextSpan(text: 'one thread.', style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.primaryNavy)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SizedBox(
          width: 460,
          child: Text(
            "AfiCare MediLink follows a patient from the local dispensary to the national referral hospital — so no one repeats a test, loses a file, or waits on a fax.",
            style: TextStyle(fontSize: 16, height: 1.6, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: onLogin,
              style: ElevatedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
              child: const Text('Create your MediLink ID'),
            ),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
                foregroundColor: AppColors.deepNavy,
              ),
              child: const Text('See how referrals work'),
            ),
          ],
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryNavy),
              alignment: Alignment.center,
              child: const Icon(Icons.check, size: 13, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('Free for patients across all 47 counties',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class _HeroPathCard extends StatelessWidget {
  const _HeroPathCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(30, 36, 30, 30),
        decoration: const BoxDecoration(color: AppColors.primaryNavy),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.lightBlue.withOpacity(.28), Colors.transparent]),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ReferralPathPreview(),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.only(top: 22),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.white.withOpacity(.18)))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '"The referral reached Kenyatta National before the patient did."',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontStyle: FontStyle.italic, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Avg. referral handoff time: 4 min, down from 2 days',
                        style: TextStyle(color: AppColors.lightBlue, fontSize: 11.5, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnersStrip extends StatelessWidget {
  const _PartnersStrip();

  static const _partners = [
    'Kenyatta National',
    'Aga Khan University Hospital',
    'Moi Teaching & Referral',
    'Mama Lucy Kibaki',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: AppColors.borderSubtle))),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Wrap(
              spacing: 40,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('LINKING FACILITIES INCLUDING',
                    style: TextStyle(fontSize: 11, letterSpacing: .8, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                for (final p in _partners)
                  Text(p, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: Color(0xFF8FA3B0))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturesSection extends StatelessWidget {
  const _FeaturesSection({required this.isWide});
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      FeatureCard(
        badgeLabel: 'P',
        title: 'For patients',
        description: 'Carry one MediLink ID between clinics. See your prescriptions, lab results, and what you owe — in one place, on your phone.',
        linkLabel: 'View patient dashboard',
        onTap: () => context.go('/patient'),
      ),
      FeatureCard(
        badgeLabel: 'C',
        title: 'For clinicians',
        description: "Search a patient's history before they finish sitting down. Send a referral upward with the record already attached.",
        linkLabel: 'View provider dashboard',
        onTap: () => context.go('/provider'),
      ),
      FeatureCard(
        badgeLabel: 'F',
        title: 'For facility admins',
        description: 'See patient volume, referral flow, and staffing load across every department — without chasing spreadsheets.',
        linkLabel: 'View admin dashboard',
        onTap: () => context.go('/admin'),
      ),
    ];

    if (!isWide) {
      return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 20), child: c)]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 28),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.deepNavy,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LandingScreen._maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 40,
                  runSpacing: 30,
                  children: [
                    const _FooterColumn(title: 'Product', items: ['Patients', 'Providers', 'Facility admin']),
                    const _FooterColumn(title: 'Network', items: ['Participating facilities', 'County coverage', 'Become a partner']),
                    const _FooterColumn(title: 'Support', items: ['Help centre', 'Data & privacy', 'Contact']),
                  ],
                ),
                const SizedBox(height: 34),
                Container(height: 1, color: Colors.white.withOpacity(.1)),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  children: [
                    Text('© 2026 AfiCare MediLink', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12.5)),
                    Text('Nairobi, Kenya', style: TextStyle(color: Colors.white.withOpacity(.55), fontSize: 12.5)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.items});
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .3)),
          const SizedBox(height: 14),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Text(item, style: TextStyle(color: Colors.white.withOpacity(.65), fontSize: 13.5)),
            ),
        ],
      ),
    );
  }
}
