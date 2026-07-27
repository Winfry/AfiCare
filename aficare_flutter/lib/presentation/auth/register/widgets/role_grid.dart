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
    final columns = width >= 860 ? 2 : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: roles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final role = roles[index];
        return RoleCard(
          role: role,
          onTap: () => context.go(role.route),
        );
      },
    );
  }
}
