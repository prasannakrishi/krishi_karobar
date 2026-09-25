import 'package:flutter/material.dart';

class CustomDecoration {
  CustomDecoration._();

  static InputDecoration uInputDecoration({
    required String labelText,
    String? prefixText,
    Icon? prefixIcon,
    IconButton? suffixIcon,
    Color? fillColor,
    EdgeInsetsGeometry? contentPadding
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      fillColor: fillColor,
      filled: fillColor != null,
      isDense: true,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    );
  }

  static Widget uTextField(
      String label,
      String value, {
        double height = 40,
        bool alignRight = false,
      }) {
    return SizedBox(
      height: height,
      child: InputDecorator(
        decoration: uInputDecoration(
          labelText: label,
        ),
        child: Align(
          alignment: alignRight
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
