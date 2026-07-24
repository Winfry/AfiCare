import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A labeled text field with a leading icon and, for password fields,
/// a show/hide toggle. Wraps [TextFormField] so it still plugs into a
/// surrounding [Form] for validation.
class BrandedTextField extends StatefulWidget {
  const BrandedTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.isPassword = false,
    this.keyboardType,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool isPassword;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  State<BrandedTextField> createState() => _BrandedTextFieldState();
}

class _BrandedTextFieldState extends State<BrandedTextField> {
  late bool _obscured = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: .2,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          style: const TextStyle(fontSize: 14.5, color: AppColors.deepNavy),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, size: 19, color: AppColors.textMuted),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 19,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
