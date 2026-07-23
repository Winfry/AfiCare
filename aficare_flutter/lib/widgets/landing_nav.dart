import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class LandingNav extends StatelessWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onGetStarted;

  const LandingNav({
    super.key,
    this.onLogin,
    this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 22),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AfiCareTheme.canopy,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'A',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
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
                      color: AfiCareTheme.ink,
                    ),
                  ),
                  Text(
                    'MEDILINK',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: AfiCareTheme.slate,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Nav links (desktop)
          if (MediaQuery.of(context).size.width > 900) ...[
            _NavLink('For patients'),
            const SizedBox(width: 34),
            _NavLink('For providers'),
            const SizedBox(width: 34),
            _NavLink('For facilities'),
            const SizedBox(width: 34),
            GestureDetector(
              onTap: onLogin,
              child: Text(
                'Log in',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AfiCareTheme.canopy,
                ),
              ),
            ),
            const SizedBox(width: 18),
          ],

          // Get started button
          ElevatedButton(
            onPressed: onGetStarted,
            child: const Text('Get started'),
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final String text;
  const _NavLink(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.ibmPlexSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: AfiCareTheme.slate,
      ),
    );
  }
}
