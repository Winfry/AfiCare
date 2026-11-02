import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/snackbar_utils.dart';

/// Free support lines in Kenya. Each one dials when tapped.
/// Checked October 2026: Kenya Red Cross 1199 is free and open 24 hours;
/// Befrienders Kenya answers calls, SMS and WhatsApp, mostly in the daytime.
class CrisisLines extends StatelessWidget {
  const CrisisLines({super.key});

  static const lines = [
    ('Kenya Red Cross (free, 24 hours)', '1199'),
    ('Befrienders Kenya (call, SMS or WhatsApp)', '0722 178 177'),
    ('Emergency', '999 or 112'),
  ];

  Future<void> _call(BuildContext context, String number) async {
    final dialable = number.split(' or ').first.replaceAll(' ', '');
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: dialable))) return;
    } catch (e) {
      debugPrint('Could not start a call: $e');
    }
    if (context.mounted) showErrorSnackBar(context, 'Could not start a call. Dial $number yourself.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (name, number) in lines)
          InkWell(
            onTap: () => _call(context, number),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, size: 16, color: Colors.grey.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ),
                  Text(number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
