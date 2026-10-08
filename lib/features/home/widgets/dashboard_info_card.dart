import 'package:flutter/material.dart';

class DashboardInfoCard extends StatelessWidget {
  const DashboardInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.accentColor = const Color(0xFF1B5E20),
    this.isTransparent = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color accentColor;
  final bool isTransparent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isTransparent ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTransparent ? accentColor.withValues(alpha: 0.8) : const Color(
              0x7EFDFDFD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
