import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';

class CHWEducationScreen extends StatelessWidget {
  const CHWEducationScreen({super.key});

  static const _topics = [
    (icon: Icons.water_drop_outlined, title: 'Safe Water & Hygiene', body: 'Encourage handwashing with soap, safe water storage, and proper sanitation to prevent diarrhoeal disease.'),
    (icon: Icons.dry_cleaning_outlined, title: 'Malaria Prevention', body: 'Sleep under insecticide-treated nets, clear stagnant water, and seek testing for fever before treatment.'),
    (icon: Icons.restaurant_outlined, title: 'Nutrition & MUAC', body: 'Support exclusive breastfeeding for 6 months, balanced diet, and routine mid-upper arm circumference checks for children.'),
    (icon: Icons.pregnant_woman_outlined, title: 'Maternal Health', body: 'Attend at least 4 ANC visits, take iron/folic acid, plan facility delivery, and watch for danger signs.'),
    (icon: Icons.phone_android_outlined, title: 'Childhood Immunization', body: 'Follow the Kenya EPI schedule: BCG & OPV at birth, Penta/PCV/Rota at 6, 10, 14 weeks, measles-rubella and more at 9 months.'),
    (icon: Icons.medication_outlined, title: 'Chronic Disease Support', body: 'For hypertension and diabetes: check blood pressure/sugar regularly, take medication as prescribed, and reduce salt and sugar.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: AppColors.canopy,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => context.go('/chw'),
        ),
        title: const Text('Health Education', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Share these key messages during community visits and home visits.',
              style: TextStyle(fontSize: 13, color: Color(0xFF1565C0), height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          ..._topics.map((t) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(t.icon, color: AppColors.canopy, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(t.body, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
