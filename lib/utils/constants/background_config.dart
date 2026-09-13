import 'package:flutter/material.dart';

import 'image_strings.dart';

class UBackgroundConfig {
  UBackgroundConfig._();

  static const bool useImage = true;
  static const String image = UImages.loginBackground;

  static const double imageOpacity = .6;
  static const double blur = 50.0;
  static const double overlayOpacity = 0.4;

  static const lightOverlay = Color(0xFFFFFFFF);
  static const darkOverlay = Color(0xFF121712);
}
