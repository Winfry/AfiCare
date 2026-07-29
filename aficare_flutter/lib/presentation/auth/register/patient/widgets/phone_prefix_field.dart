import 'package:flutter/material.dart';

class PhonePrefixField extends StatelessWidget {
  const PhonePrefixField({
    super.key,
    required this.controller,
    required this.validator,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Phone Number',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF55708A),
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.phone,
          validator: validator,
          style: const TextStyle(
            fontSize: 14.5,
            color: Color(0xFF152A45),
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: '712 345 678',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            prefixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.phone_outlined, size: 19, color: Color(0xFF55708A)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: Color(0xFFDCE3EA))),
                  ),
                  child: const Text(
                    '+254',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF55708A),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDCE3EA), width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF206B5D), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
