import 'package:flutter/material.dart';

class RegisterRole {
  const RegisterRole({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconCircleColor,
    required this.titleColor,
    required this.route,
    this.fullWidth = false,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Background color for the icon circle.
  final Color iconCircleColor;

  /// Color for the role title text.
  final Color titleColor;

  final String route;

  /// When true the card spans the full grid width.
  final bool fullWidth;
}
