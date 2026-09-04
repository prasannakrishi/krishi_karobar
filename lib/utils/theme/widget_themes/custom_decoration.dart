
import 'package:flutter/material.dart';

class CustomDecoration {
  static InputDecoration uInputDecoration({ required String labelText, String? prefixText, Icon? prefixIcon, IconButton? suffixIcon, Color? fillColor}) {
    return InputDecoration(
      labelText: labelText,
      prefixText: prefixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      fillColor: fillColor ?? const Color.fromARGB(37, 255, 250, 250),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA5D6A7), width: 3),
      ),
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: const TextStyle(fontSize: 14),
      isDense: true
    );
  }
  static Widget uTextField(String label, String value, {bool alignRight = false}) {
    return SizedBox(
      height: 40,
      child: InputDecorator(
        decoration: CustomDecoration.uInputDecoration( labelText: label),
        child: Align(
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      )
    );
  }

  static Widget buildCollapsibleCard({
    required String title,
    required bool isCollapsed,
    required VoidCallback onTap,
    required Widget child,
    required Widget collapsedChild,
  }) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Icon(isCollapsed ? Icons.expand_more : Icons.expand_less),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                if (isCollapsed) ...[
                  const SizedBox(width: 5),
                  Expanded(child: collapsedChild),
                ],
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.all(8.0),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState:
            isCollapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }

  static Widget buildMetricCard(String title, ValueNotifier<String> notifier,
      String defaultValue,
      {String prefix = ''}) {
    return Card(
        elevation: 3,
        color: const Color.fromARGB(255, 128, 241, 200),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: ValueListenableBuilder<String>(
            valueListenable: notifier,
            builder: (context, value, child) {
              return Column(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 5),
                  Text(
                    value.isNotEmpty ? '$prefix$value' : defaultValue,
                    style: const TextStyle(
                        fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ],
              );
            },
          ),
        ),

    );
  }
  static Widget buildReadOnlyField({
    required String label,
    required ValueNotifier<String> valueNotifier,
    String prefix = '',
    TextAlign alignment = TextAlign.start,
  }) {
    return ValueListenableBuilder<String>(
      valueListenable: valueNotifier,
      builder: (context, value, child) {
        return TextField(
          readOnly: true,
          decoration: uInputDecoration(
            labelText: label,
            prefixText: value.isNotEmpty ? prefix : null,
          ),
          controller: TextEditingController(text: value),
          style: const TextStyle(fontSize: 16),
          textAlign: alignment,
        );
      },
    );
  }





}