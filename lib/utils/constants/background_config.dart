import 'package:flutter/material.dart';

import 'image_strings.dart';

class UBackgroundConfig {
  UBackgroundConfig._();

  static const bool useImage = true;
  static const String image = UImages.loginBackground;

  static const double imageOpacity = 0.16;
  static const double blur = 10.0;
  static const double overlayOpacity = 0.78;

  static const lightOverlay = Color(0xFFF7FAF7);
  static const darkOverlay = Color(0xFF121712);
}
