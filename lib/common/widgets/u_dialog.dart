import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'u_button.dart';
import 'u_display_size.dart';

class UDialog extends StatelessWidget {
  const UDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmText = 'OK',
    this.cancelText,
    this.onConfirm,
    this.onCancel,
    this.isDanger = false,
    this.displaySize,
  });

  final String title;
  final Widget content;
  final String confirmText;
  final String? cancelText;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final bool isDanger;
  final UDisplaySize? displaySize;

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    String confirmText = 'OK',
    String? cancelText,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    bool isDanger = false,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => UDialog(
        title: title,
        content: content,
        confirmText: confirmText,
        cancelText: cancelText,
        onConfirm: onConfirm,
        onCancel: onCancel,
        isDanger: isDanger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = displaySize ?? UDisplaySizeController.instance.displaySize.value;

      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size.borderRadius * 1.5),
        ),
        titlePadding: EdgeInsets.all(size.spacing * 1.2),
        contentPadding: EdgeInsets.symmetric(horizontal: size.spacing * 1.2),
        actionsPadding: EdgeInsets.all(size.spacing),
        title: Text(
          title,
          style: TextStyle(
            fontSize: size.fontSize + 2,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        content: SingleChildScrollView(child: content),
        actions: [
          if (cancelText != null)
            UButton(
              text: cancelText!,
              style: UButtonStyle.text,
              onPressed: () {
                onCancel?.call();
                Navigator.of(context).pop();
              },
            ),
          UButton(
            text: confirmText,
            style: isDanger ? UButtonStyle.danger : UButtonStyle.primary,
            onPressed: () {
              onConfirm?.call();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    });
  }
}
