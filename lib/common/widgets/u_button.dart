import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'u_display_size.dart';

enum UButtonStyle {
  primary,
  secondary,
  outline,
  text,
  danger,
}

class UButton extends StatelessWidget {
  const UButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.style = UButtonStyle.primary,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.displaySize,
  });

  final String text;
  final VoidCallback? onPressed;
  final UButtonStyle style;
  final Widget? icon;
  final bool isLoading;
  final bool isFullWidth;
  final UDisplaySize? displaySize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = displaySize ?? UDisplaySizeController.instance.displaySize.value;
      const primaryColor = Color(0xFF1B5E20);

      Widget childContent;
      if (isLoading) {
        childContent = SizedBox(
          width: size.iconSize,
          height: size.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              style == UButtonStyle.outline || style == UButtonStyle.text
                  ? primaryColor
                  : Colors.white,
            ),
          ),
        );
      } else if (icon != null) {
        childContent = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon!,
            SizedBox(width: size.spacing / 2),
            Text(
              text,
              style: TextStyle(
                fontSize: size.fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        );
      } else {
        childContent = Text(
          text,
          style: TextStyle(
            fontSize: size.fontSize,
            fontWeight: FontWeight.bold,
          ),
        );
      }

      Widget button;

      switch (style) {
        case UButtonStyle.primary:
          button = ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: size.buttonPadding,
              minimumSize: Size(0, size.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size.borderRadius),
              ),
            ),
            child: childContent,
          );
          break;

        case UButtonStyle.secondary:
          button = ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8F5E9),
              foregroundColor: primaryColor,
              padding: size.buttonPadding,
              minimumSize: Size(0, size.buttonHeight),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size.borderRadius),
              ),
            ),
            child: childContent,
          );
          break;

        case UButtonStyle.outline:
          button = OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              padding: size.buttonPadding,
              minimumSize: Size(0, size.buttonHeight),
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size.borderRadius),
              ),
            ),
            child: childContent,
          );
          break;

        case UButtonStyle.danger:
          button = ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: size.buttonPadding,
              minimumSize: Size(0, size.buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(size.borderRadius),
              ),
            ),
            child: childContent,
          );
          break;

        case UButtonStyle.text:
          button = TextButton(
            onPressed: isLoading ? null : onPressed,
            style: TextButton.styleFrom(
              foregroundColor: primaryColor,
              padding: size.buttonPadding,
              minimumSize: Size(0, size.buttonHeight),
            ),
            child: childContent,
          );
          break;
      }

      if (isFullWidth) {
        return SizedBox(
          width: double.infinity,
          child: button,
        );
      }

      return button;
    });
  }
}
