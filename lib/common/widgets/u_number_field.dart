import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'u_display_size.dart';
import 'u_text_field.dart';

class UNumberField extends StatelessWidget {
  const UNumberField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.required = false,
    this.isDecimal = false,
    this.allowNegative = false,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.enabled = true,
    this.readOnly = false,
    this.maxLength,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.displaySize,
  });

  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool required;
  final bool isDecimal;
  final bool allowNegative;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final bool enabled;
  final bool readOnly;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final UDisplaySize? displaySize;

  @override
  Widget build(BuildContext context) {
    final formatters = <TextInputFormatter>[];

    if (isDecimal) {
      formatters.add(
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'^-?\d*\.?\d*' : r'^\d*\.?\d*'),
        ),
      );
    } else {
      formatters.add(
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'^-?\d*' : r'^\d*'),
        ),
      );
    }

    return UTextField(
      controller: controller,
      labelText: labelText,
      hintText: hintText,
      required: required,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefixText: prefixText,
      suffixText: suffixText,
      keyboardType: TextInputType.numberWithOptions(
        decimal: isDecimal,
        signed: allowNegative,
      ),
      inputFormatters: formatters,
      enabled: enabled,
      readOnly: readOnly,
      maxLength: maxLength,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      displaySize: displaySize,
    );
  }
}
