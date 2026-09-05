import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class UChipTheme {
  UChipTheme._();

  static const lightChipTheme = ChipThemeData(
    disabledColor: UColors.grey,
    labelStyle: TextStyle(color: UColors.textPrimary),
    selectedColor: UColors.primaryLight,
    checkmarkColor: UColors.primary,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static const darkChipTheme = ChipThemeData(
    disabledColor: UColors.darkerGrey,
    labelStyle: TextStyle(color: UColors.white),
    selectedColor: UColors.darkContainer,
    checkmarkColor: UColors.white,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );
}
