import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aficare_flutter/utils/theme.dart';

class MediCard extends StatelessWidget {
  final String patientName;
  final String mediLinkId;
  final String? dateOfBirth;
  final String? bloodType;
  final String? allergies;

  const MediCard({
    super.key,
    required this.patientName,
    required this.mediLinkId,
    this.dateOfBirth,
    this.bloodType,
    this.allergies,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AfiCareTheme.canopy,
            AfiCareTheme.canopy2,
            AfiCareTheme.canopy.withOpacity( 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AfiCareTheme.canopy.withOpacity( 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.medical_information_outlined,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'MediLink ID',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            patientName,
            style: GoogleFonts.fraunces(
              fontSize: 21,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mediLinkId,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity( 0.8),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dateOfBirth != null)
                _buildChip(Icons.cake_outlined, dateOfBirth!),
              if (bloodType != null)
                _buildChip(Icons.bloodtype_outlined, bloodType!),
              if (allergies != null)
                _buildChip(Icons.warning_amber_outlined, allergies!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity( 0.8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
