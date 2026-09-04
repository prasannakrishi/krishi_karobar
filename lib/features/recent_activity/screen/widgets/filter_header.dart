import 'package:flutter/material.dart';

class FilterHeader extends StatelessWidget {
  const FilterHeader({
    super.key,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  final String title;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.blue : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: isActive ? Colors.blue : Colors.grey,
          ),
        ],

      ),
    );
  }
}