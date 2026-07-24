import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TimelineEntry {
  const TimelineEntry({required this.icon, required this.title, required this.meta});
  final IconData icon;
  final String title;
  final String meta;
}

class TimelineList extends StatelessWidget {
  const TimelineList({super.key, required this.entries, this.isDark = false});

  final List<TimelineEntry> entries;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lineColor = isDark ? Colors.white.withOpacity(.12) : AppColors.borderSubtle;
    final metaColor = isDark ? const Color(0xFF93A0AB) : AppColors.textMuted;
    final dotBg = isDark ? const Color(0xFF2E2E2E) : AppColors.mistBackground;

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 29,
                      height: 29,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: dotBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.white.withOpacity(.1) : AppColors.borderSubtle),
                      ),
                      child: Icon(entries[i].icon, size: 13, color: isDark ? Colors.white70 : AppColors.deepNavy),
                    ),
                    if (i != entries.length - 1) Expanded(child: Container(width: 1.5, color: lineColor)),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == entries.length - 1 ? 0 : 20, top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entries[i].title,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.deepNavy)),
                        const SizedBox(height: 2),
                        Text(entries[i].meta, style: TextStyle(fontSize: 12, color: metaColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
