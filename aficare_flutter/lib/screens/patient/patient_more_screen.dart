import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/dependent_provider.dart';
import '../../theme/patient_tokens.dart';
import 'patient_nav.dart';
import 'widgets/patient_ui.dart';

/// The "More of AfiCare" page (`#more`): every patient tool that is not
/// in the sidebar, as grouped two-column grids of tiles.
class PatientMoreScreen extends StatelessWidget {
  const PatientMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDependent = context.watch<DependentProvider>().isViewingDependent;
    final isMobile = PT.isMobile(context);

    final sections = <Widget>[];
    for (final group in patientMore.entries) {
      final items = [
        for (final d in group.value)
          if (!(isDependent && d.adultOnly) && !(d.phoneOnly && !isMobile)) d,
      ];
      if (items.isEmpty) continue;
      sections.add(Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PHeading(group.key),
            LayoutBuilder(builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final d in items)
                    SizedBox(width: w, child: _MoreTile(dest: d, onTap: () => context.go(d.route))),
                ],
              );
            }),
          ],
        ),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PScreenHead(
            eyebrow: 'Here when you need us',
            title: 'More of AfiCare',
            subtitle: "All the other tools are still here. We've simply made a little more room for your everyday care.",
          ),
          ...sections,
        ],
      ),
    );
  }
}

/// `.moreitem`.
class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.dest, required this.onTap});

  final PatientDest dest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PT.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PT.rRow),
        side: const BorderSide(color: PT.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PT.rRow),
        hoverColor: PT.searchFill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(dest.icon, size: 19, color: PT.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(dest.label,
                    style: PT.rowTitle().copyWith(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
