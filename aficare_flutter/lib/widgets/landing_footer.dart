import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class LandingFooter extends StatelessWidget {
  const LandingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Container(
      color: AfiCareTheme.canopy,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 24,
        vertical: 50,
      ),
      child: Column(
        children: [
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 30, child: _buildLogoColumn()),
                    const SizedBox(width: 30),
                    Expanded(flex: 20, child: _buildProductColumn()),
                    const SizedBox(width: 30),
                    Expanded(flex: 20, child: _buildNetworkColumn()),
                    const SizedBox(width: 30),
                    Expanded(flex: 20, child: _buildSupportColumn()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogoColumn(),
                    const SizedBox(height: 30),
                    _buildProductColumn(),
                    const SizedBox(height: 20),
                    _buildNetworkColumn(),
                    const SizedBox(height: 20),
                    _buildSupportColumn(),
                  ],
                ),

          const SizedBox(height: 40),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity( 0.15),
          ),

          const SizedBox(height: 20),

          // Bottom
          Row(
            children: [
              Text(
                '© 2025 AfiCare Health Technologies',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity( 0.5),
                ),
              ),
              const Spacer(),
              Text(
                'Nairobi, Kenya',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity( 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogoColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
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
            Text(
              'AfiCare',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Patient-owned healthcare records for Africa.',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 14,
            color: Colors.white.withOpacity( 0.6),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildProductColumn() {
    return _FooterColumn(
      title: 'Product',
      items: ['Features', 'Pricing', 'For patients', 'For providers', 'For facilities'],
    );
  }

  Widget _buildNetworkColumn() {
    return _FooterColumn(
      title: 'Network',
      items: ['County partners', 'Facility directory', 'Referral network', 'Data standards'],
    );
  }

  Widget _buildSupportColumn() {
    return _FooterColumn(
      title: 'Support',
      items: ['Help centre', 'Contact us', 'Privacy policy', 'Terms of service'],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  final String title;
  final List<String> items;

  const _FooterColumn({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(
            item,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 13,
              color: Colors.white.withOpacity( 0.6),
            ),
          ),
        )),
      ],
    );
  }
}
