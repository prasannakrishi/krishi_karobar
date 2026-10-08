import 'package:flutter/material.dart';
import 'package:get/get.dart';

class USnackbar {
  USnackbar._();

  static void success({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE8F5E9),
      colorText: const Color(0xFF1B5E20),
      icon: const Icon(Icons.check_circle, color: Color(0xFF1B5E20)),
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: duration,
    );
  }

  static void error({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
  }) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFFEBEE),
      colorText: const Color(0xFFB71C1C),
      icon: const Icon(Icons.error, color: Color(0xFFB71C1C)),
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: duration,
    );
  }

  static void warning({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFFFF3E0),
      colorText: const Color(0xFFE65100),
      icon: const Icon(Icons.warning, color: Color(0xFFE65100)),
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: duration,
    );
  }

  static void info({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message ?? '',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFE3F2FD),
      colorText: const Color(0xFF0D47A1),
      icon: const Icon(Icons.info, color: Color(0xFF0D47A1)),
      margin: const EdgeInsets.all(12),
      borderRadius: 10,
      duration: duration,
    );
  }
}
