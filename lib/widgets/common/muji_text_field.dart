import 'package:flutter/material.dart';

/// シンプルなテキスト入力フィールドコンポーネント
class SimpleTextField extends StatelessWidget {
  final String? label;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool readOnly;
  final TextInputType? keyboardType;
  final int? maxLines;

  const SimpleTextField({
    super.key,
    this.label,
    this.hintText,
    this.controller,
    this.validator,
    this.readOnly = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.4,
                color: Color(0xFF7F7F7F),
              ),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          validator: validator,
          readOnly: readOnly,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: const Color(0xFFF9F9F9),
            border: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF333333)),
              borderRadius: BorderRadius.circular(12),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(12),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.red),
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          style: TextStyle(
            fontSize: maxLines == 1 ? 14 : 16,
          ),
        ),
      ],
    );
  }
}

/// シンプルなセクションラベルコンポーネント
class SimpleSectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const SimpleSectionLabel({
    super.key,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.4,
              color: Color(0xFF7F7F7F),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
