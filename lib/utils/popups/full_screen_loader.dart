
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/colors.dart';
import '../helper/helper_functions.dart';

class UFullScreenLoader {
  static bool _isLoaderShowing = false;

  /// Show full screen loading dialog
  static void openLoadingDialog(String text, String animation) {
    if (_isLoaderShowing) return;

    _isLoaderShowing = true;
    showDialog(
      context: Get.overlayContext!,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: UHelperFunctions.isDarkMode(Get.context!)
              ? UColors.dark
              : UColors.white,
          width: double.infinity,
          height: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  text,
                  style: Theme.of(Get.context!).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // This 'then' block executes when the dialog is popped.
      // We ensure our flag is reset to false, no matter how the dialog is closed.
      _isLoaderShowing = false;
    });
  }

  /// Convenience wrapper for starting loader
  static void startLoading({String text = 'Loading...', String animation = ''}) {
    openLoadingDialog(text, animation);
  }

  /// Stop loader safely
  static void stopLoading() {
    if (_isLoaderShowing) {
      // Check if a route can be popped before popping it.
      if (Navigator.of(Get.overlayContext!).canPop()) {
        Navigator.of(Get.overlayContext!).pop();
      }
      _isLoaderShowing = false;
    }
  }
}