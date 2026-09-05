import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class UTextTheme {
  UTextTheme._();

  static const _font = 'Poppins';

  static TextTheme lightTextTheme = const TextTheme(
    displayLarge: TextStyle(
      fontFamily: _font,
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: UColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: _font,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      color: UColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: _font,
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: UColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _font,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: UColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: _font,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: UColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontFamily: _font,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: UColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: UColors.textSecondary,
    ),
    bodyLarge: TextStyle(
      fontFamily: _font,
      fontSize: 16,
      color: UColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: _font,
      fontSize: 14,
      color: UColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontFamily: _font,
      fontSize: 12,
      color: UColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: _font,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: UColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: _font,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: UColors.textSecondary,
    ),
  );

  static TextTheme darkTextTheme = lightTextTheme
      .apply(bodyColor: UColors.white, displayColor: UColors.white)
      .copyWith(
        titleSmall: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: UColors.grey,
        ),
        bodySmall: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          color: UColors.grey,
        ),
        labelMedium: const TextStyle(
          fontFamily: _font,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: UColors.grey,
        ),
      );
}
