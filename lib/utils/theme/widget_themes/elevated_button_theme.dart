import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class UElevatedButtonTheme {
  UElevatedButtonTheme._();

  static final lightElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 1,
      backgroundColor: UColors.primary,
      foregroundColor: UColors.white,
      disabledBackgroundColor: UColors.grey,
      disabledForegroundColor: UColors.darkGrey,
      padding: const EdgeInsets.symmetric(vertical: USizes.buttonHeight),
      textStyle: const TextStyle(
        fontSize: USizes.fontSizeMd,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(USizes.buttonRadius),
      ),
    ),
  );

  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 1,
      backgroundColor: UColors.primary,
      foregroundColor: UColors.white,
      disabledBackgroundColor: UColors.darkerGrey,
      disabledForegroundColor: UColors.grey,
      padding: const EdgeInsets.symmetric(vertical: USizes.buttonHeight),
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
