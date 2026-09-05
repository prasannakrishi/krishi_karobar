import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class UCheckboxTheme {
  UCheckboxTheme._();

  static final lightCheckboxTheme = CheckboxThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(USizes.xs),
    ),
    checkColor: const WidgetStatePropertyAll(UColors.white),
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? UColors.primary
          : Colors.transparent,
    ),
  );

  static final darkCheckboxTheme = CheckboxThemeData(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(USizes.xs),
    ),
    checkColor: const WidgetStatePropertyAll(UColors.white),
    fillColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? UColors.primary
          : Colors.transparent,
    ),
  );
}
