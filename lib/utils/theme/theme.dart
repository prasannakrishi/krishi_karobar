import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'widget_themes/appbar_theme.dart';
import 'widget_themes/bottom_sheet_theme.dart';
import 'widget_themes/checkbox_theme.dart';
import 'widget_themes/chip_theme.dart';
import 'widget_themes/elevated_button_theme.dart';
import 'widget_themes/outlined_button_theme.dart';
import 'widget_themes/text_field_theme.dart';
import 'widget_themes/text_theme.dart';

class UAppTheme {
  UAppTheme._();

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.light,
    primaryColor: UColors.primary,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: UColors.primary,
      brightness: Brightness.light,
    ),
    disabledColor: UColors.darkGrey,
    textTheme: UTextTheme.lightTextTheme,
    appBarTheme: UAppBarTheme.lightAppBarTheme,
    chipTheme: UChipTheme.lightChipTheme,
    checkboxTheme: UCheckboxTheme.lightCheckboxTheme,
    bottomSheetTheme: UBottomSheetTheme.lightBottomSheetTheme,
    elevatedButtonTheme: UElevatedButtonTheme.lightElevatedButtonTheme,
    outlinedButtonTheme: UOutlinedButtonTheme.lightOutlinedButtonTheme,
    inputDecorationTheme: UTextFormFieldTheme.lightInputDecorationTheme,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.dark,
    primaryColor: UColors.primary,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: UColors.primary,
      brightness: Brightness.dark,
    ),
    disabledColor: UColors.darkGrey,
    textTheme: UTextTheme.darkTextTheme,
    appBarTheme: UAppBarTheme.darkAppBarTheme,
    chipTheme: UChipTheme.darkChipTheme,
    checkboxTheme: UCheckboxTheme.darkCheckboxTheme,
    bottomSheetTheme: UBottomSheetTheme.darkBottomSheetTheme,
    elevatedButtonTheme: UElevatedButtonTheme.darkElevatedButtonTheme,
    outlinedButtonTheme: UOutlinedButtonTheme.darkOutlinedButtonTheme,
    inputDecorationTheme: UTextFormFieldTheme.darkInputDecorationTheme,
  );
}
