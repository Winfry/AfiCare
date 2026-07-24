import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MediLinkIdCard extends StatelessWidget {
  const MediLinkIdCard({
    super.key,
    required this.patientName,
    required this.mediLinkId,
    required this.county,
    required this.insuranceLinked,
    required this.tier,
  });

  final String patientName;
  final String mediLinkId;
  final String county;
  final bool insuranceLinked;
  final String tier;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryNavy, AppColors.navyGradientMid, Color(0xFF14335A)],
            stops: [0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.lightBlue.withOpacity(.28), Colors.transparent],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEDILINK ID',
                              style: TextStyle(
                                color: Colors.white.withOpacity(.7),
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              patientName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              mediLinkId,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 13,
                                letterSpacing: .3,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.lightBlue,
                        ),
                        child: Text(
                          tier,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.deepNavy,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _Chip('Registered · $county'),
                      if (insuranceLinked) const _Chip('NHIF/SHA linked'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.3)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
    );
  }
}
