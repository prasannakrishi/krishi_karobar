import 'package:flutter/material.dart';

class USection extends StatelessWidget {
  const USection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
            if (trailing != null)
              GestureDetector(
                onTap: onTrailingTap,
                child: trailing,
              ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
