import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class LandingHero extends StatelessWidget {
  final VoidCallback? onGetStarted;
  final VoidCallback? onLearnMore;

  const LandingHero({
    super.key,
    this.onGetStarted,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 900;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 24,
        vertical: isWide ? 56 : 40,
      ),
      child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text column
        Expanded(
          flex: 55,
          child: _buildTextContent(),
        ),
        const SizedBox(width: 60),
        // Card column
        Expanded(
          flex: 45,
          child: _buildPathCard(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildTextContent(),
        const SizedBox(height: 40),
        _buildPathCard(),
      ],
    );
  }

  Widget _buildTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AfiCareTheme.canopy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Connected care, county to county',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AfiCareTheme.canopy,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Heading
        Text(
          'Every referral, every record, one thread.',
          style: GoogleFonts.fraunces(
            fontSize: 56,
            fontWeight: FontWeight.w700,
            color: AfiCareTheme.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 20),

        // Subtitle
        SizedBox(
          width: 460,
          child: Text(
            'AfiCare MediLink gives every patient a single, secure health '
            'record that follows them from dispensary to national referral. '
            'Providers see the full picture. Families stay informed.',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 17,
              color: AfiCareTheme.slate,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // CTAs
        Row(
          children: [
            ElevatedButton(
              onPressed: onGetStarted,
              child: const Text('Get started'),
            ),
            const SizedBox(width: 14),
            OutlinedButton(
              onPressed: onLearnMore,
              child: const Text('Learn more'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Note
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AfiCareTheme.marigold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 14, color: AfiCareTheme.marigold),
                  const SizedBox(width: 4),
                  Text(
                    'Free tier',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AfiCareTheme.marigold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Free for patients across all 47 counties',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: AfiCareTheme.slate,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPathCard() {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AfiCareTheme.canopy,
            AfiCareTheme.canopy2,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AfiCareTheme.canopy.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A referral, start to finish',
            style: GoogleFonts.fraunces(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 28),

          // Path visualization
          Row(
            children: [
              _PathNode('Dispensary', true),
              _PathLine(),
              _PathNode('Sub-county', false),
              _PathLine(),
              _PathNode('County', false),
              _PathLine(),
              _PathNode('National', false),
            ],
          ),

          const SizedBox(height: 28),

          // Quote
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '"My mother\'s records followed her from Makueni to Kenyatta. '
              'No papers lost." — Grace W.',
              style: GoogleFonts.ibmPlexSans(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.9),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathNode extends StatelessWidget {
  final String label;
  final bool isActive;
  const _PathNode(this.label, this.isActive);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: isActive ? AfiCareTheme.marigold : Colors.white.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: AfiCareTheme.marigold.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.ibmPlexSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _PathLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: CustomPaint(
          painter: _DashedLinePainter(),
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
