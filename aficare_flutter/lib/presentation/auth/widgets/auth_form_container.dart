import 'package:flutter/material.dart';

class AuthFormContainer extends StatelessWidget {
  const AuthFormContainer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 420,
        ),
        child: child,
      ),
    );
  }
}
