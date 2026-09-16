import 'package:flutter/material.dart';

/// Shown when a permission-gated screen is reached without the required
/// permission - e.g. someone navigates here directly even though the nav
/// tile that normally leads here was hidden. UI hiding alone is not
/// security (spec section 17), so every gated screen re-checks itself.
class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            "You don't have permission to perform this action.",
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
