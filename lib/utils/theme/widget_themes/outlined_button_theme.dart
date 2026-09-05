import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class UOutlinedButtonTheme {
  UOutlinedButtonTheme._();

  static final lightOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: UColors.primary,
      side: const BorderSide(color: UColors.primary),
      padding: const EdgeInsets.symmetric(
        vertical: USizes.buttonHeight,
        horizontal: 20,
      ),
      textStyle: const TextStyle(
        fontSize: USizes.fontSizeMd,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(USizes.buttonRadius),
      ),
    ),
  );

  static final darkOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: UColors.white,
      side: const BorderSide(color: UColors.primary),
      padding: const EdgeInsets.symmetric(
        vertical: USizes.buttonHeight,
        horizontal: 20,
      ),
      textStyle: const TextStyle(
        fontSize: USizes.fontSizeMd,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(USizes.buttonRadius),
      ),
    ),
  );
}
