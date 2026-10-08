import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'u_display_size.dart';
import 'u_text_field.dart';

class USearchBar extends StatelessWidget {
  const USearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.displaySize,
  });

  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final UDisplaySize? displaySize;

  @override
  Widget build(BuildContext context) {
    return UTextField(
      controller: controller,
      hintText: hintText,
      prefixIcon: const Icon(Iconsax.search_normal, size: 18),
      showClearButton: true,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      displaySize: displaySize,
    );
  }
}
