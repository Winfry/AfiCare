import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppointmentEntry {
  const AppointmentEntry({required this.time, required this.who, required this.what});
  final String time;
  final String who;
  final String what;
}

class AppointmentList extends StatelessWidget {
  const AppointmentList({super.key, required this.entries, this.isDark = false});

  final List<AppointmentEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? Colors.white.withOpacity(.08) : AppColors.borderSubtle;
    final metaColor = isDark ? const Color(0xFF93A0AB) : AppColors.textMuted;
    final chipBg = isDark ? Colors.white.withOpacity(.07) : AppColors.mistBackground;

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: i == entries.length - 1 ? null : Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  constraints: const BoxConstraints(minWidth: 52),
                  decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    entries[i].time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : AppColors.deepNavy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entries[i].who,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppColors.deepNavy)),
                      Text(entries[i].what, style: TextStyle(fontSize: 12, color: metaColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
