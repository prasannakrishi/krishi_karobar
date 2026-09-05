import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class UTextFormFieldTheme {
  UTextFormFieldTheme._();

  static InputDecorationTheme lightInputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: UColors.white.withValues(alpha: 0.72),
    errorMaxLines: 2,
    prefixIconColor: UColors.textSecondary,
    suffixIconColor: UColors.textSecondary,
    labelStyle: const TextStyle(
      fontSize: USizes.fontSizeSm,
      color: UColors.textSecondary,
    ),
    hintStyle: const TextStyle(
      fontSize: USizes.fontSizeSm,
      color: UColors.textSecondary,
    ),
    floatingLabelStyle: const TextStyle(
      color: UColors.primary,
      fontWeight: FontWeight.w500,
    ),
    border: _border(UColors.borderLight),
    enabledBorder: _border(UColors.borderLight),
    focusedBorder: _border(UColors.primary, 1.5),
    errorBorder: _border(UColors.error),
    focusedErrorBorder: _border(UColors.error, 1.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static InputDecorationTheme darkInputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: UColors.darkSurface.withValues(alpha: 0.78),
    errorMaxLines: 2,
    prefixIconColor: UColors.grey,
    suffixIconColor: UColors.grey,
    labelStyle: const TextStyle(
      fontSize: USizes.fontSizeSm,
      color: UColors.grey,
    ),
    hintStyle: const TextStyle(
      fontSize: USizes.fontSizeSm,
      color: UColors.grey,
    ),
    floatingLabelStyle: const TextStyle(
      color: UColors.primary,
      fontWeight: FontWeight.w500,
    ),
    border: _border(UColors.borderDark),
    enabledBorder: _border(UColors.borderDark),
    focusedBorder: _border(UColors.primary, 1.5),
    errorBorder: _border(UColors.error),
    focusedErrorBorder: _border(UColors.error, 1.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  static OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(USizes.inputFieldRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
