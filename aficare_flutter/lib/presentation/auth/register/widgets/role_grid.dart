import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'role_card.dart';
import 'role_model.dart';

class RoleGrid extends StatelessWidget {
  const RoleGrid({
    super.key,
    required this.roles,
  });

  final List<RegisterRole> roles;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 860;

    if (!isDesktop) {
      return Column(
        children: roles.map((role) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RoleCard(role: role, onTap: () => context.go(role.route)),
        )).toList(),
      );
    }

    // Desktop: 2 columns, admin spans full width
    final pairs = <List<RegisterRole>>[];
    for (int i = 0; i < roles.length; i++) {
      if (roles[i].fullWidth) {
        pairs.add([roles[i]]);
      } else if (i + 1 < roles.length && !roles[i + 1].fullWidth) {
        pairs.add([roles[i], roles[i + 1]]);
        i++;
      } else {
        pairs.add([roles[i]]);
      }
    }

    return Column(
      children: pairs.map((pair) {
        if (pair.length == 1) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: constraints.maxWidth,
                child: RoleCard(role: pair[0], onTap: () => context.go(pair[0].route)),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: pair.map((role) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: role == pair[1] ? 8 : 0, right: role == pair[0] ? 8 : 0),
                child: RoleCard(role: role, onTap: () => context.go(role.route)),
              ),
            )).toList(),
          ),
        );
      }).toList(),
    );
  }
}
