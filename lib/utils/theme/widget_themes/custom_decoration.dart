import 'package:flutter/material.dart';

class CustomDecoration {
  CustomDecoration._();

  static InputDecoration uInputDecoration({
    required String labelText,
    String? prefixText,
    Icon? prefixIcon,
    IconButton? suffixIcon,
    Color? fillColor,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      fillColor: fillColor,
      filled: fillColor != null,
      isDense: true,
    );
  }

  static Widget uTextField(
    String label,
    String value, {
    bool alignRight = false,
  }) {
    return SizedBox(
      height: 48,
      child: InputDecorator(
        decoration: uInputDecoration(labelText: label),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
