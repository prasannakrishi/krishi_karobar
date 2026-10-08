import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'u_button.dart';

class UEmptyState extends StatelessWidget {
  const UEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Iconsax.folder_open,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              UButton(
                text: actionLabel!,
                onPressed: onAction,
                style: UButtonStyle.secondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
