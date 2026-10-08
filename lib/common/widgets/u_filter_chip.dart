import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'u_display_size.dart';

class UFilterChip extends StatelessWidget {
  const UFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
    this.displaySize,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final int? count;
  final UDisplaySize? displaySize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = displaySize ?? UDisplaySizeController.instance.displaySize.value;
      final primaryColor = const Color(0xFF1B5E20);

      final labelText = count != null ? '$label ($count)' : label;

      return ChoiceChip(
        label: Text(
          labelText,
          style: TextStyle(
            fontSize: size.labelSize,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
        selected: selected,
        selectedColor: primaryColor,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size.borderRadius * 2),
          side: BorderSide(
            color: selected ? primaryColor : Colors.grey.shade300,
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: size.spacing / 2,
          vertical: size.spacing / 4,
        ),
        onSelected: onSelected,
      );
    });
  }
}
