import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class HistoryFilterHeader extends StatelessWidget {
  const HistoryFilterHeader({
    super.key,
    required this.isActive,
    required this.onTap,
  });

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Badge(
        isLabelVisible: isActive,
        child: const Icon(Iconsax.filter),
      ),
      tooltip: 'Filter',
    );
  }
}