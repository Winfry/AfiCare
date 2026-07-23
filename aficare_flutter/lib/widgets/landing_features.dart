import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class LandingFeatures extends StatelessWidget {
  const LandingFeatures({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          Text(
            'Built for Kenya\'s health system',
            style: GoogleFonts.fraunces(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: AfiCareTheme.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'From dispensary to national referral, AfiCare connects every level.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              color: AfiCareTheme.slate,
            ),
          ),
          const SizedBox(height: 44),

          isWide
              ? Row(
                  children: const [
                    Expanded(child: _FeatureCard(
                      icon: Icons.person_outline,
                      title: 'For Patients',
                      description: 'Your health record, always with you. Share with any provider, anywhere in Kenya.',
                      tier: 'Free',
                    )),
                    SizedBox(width: 28),
                    Expanded(child: _FeatureCard(
                      icon: Icons.medical_services_outlined,
                      title: 'For Clinicians',
                      description: 'See the full patient history. Make informed decisions. Refer with confidence.',
                      tier: 'Provider',
                    )),
                    SizedBox(width: 28),
                    Expanded(child: _FeatureCard(
                      icon: Icons.business_outlined,
                      title: 'For Facility Admins',
                      description: 'Manage staff, track referrals, and monitor facility performance in real-time.',
                      tier: 'Facility',
                    )),
                  ],
                )
              : Column(
                  children: const [
                    _FeatureCard(
                      icon: Icons.person_outline,
                      title: 'For Patients',
                      description: 'Your health record, always with you. Share with any provider, anywhere in Kenya.',
                      tier: 'Free',
                    ),
                    SizedBox(height: 28),
                    _FeatureCard(
                      icon: Icons.medical_services_outlined,
                      title: 'For Clinicians',
                      description: 'See the full patient history. Make informed decisions. Refer with confidence.',
                      tier: 'Provider',
                    ),
                    SizedBox(height: 28),
                    _FeatureCard(
                      icon: Icons.business_outlined,
                      title: 'For Facility Admins',
                      description: 'Manage staff, track referrals, and monitor facility performance in real-time.',
                      tier: 'Facility',
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String tier;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AfiCareTheme.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AfiCareTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AfiCareTheme.marigold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tier,
              style: GoogleFonts.ibmPlexSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AfiCareTheme.marigold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Icon(icon, size: 28, color: AfiCareTheme.canopy),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: AfiCareTheme.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 14,
              color: AfiCareTheme.slate,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {},
            child: Text(
              'Learn more →',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: AfiCareTheme.canopy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
