import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/common/widgets/appbar.dart';
import 'package:krishi_karobar/features/controllers.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UAppBar(title: 'Profile Details',),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: CircleAvatar(
                    radius: 50,
                    child: Icon(Iconsax.user_edit, size: 50),
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            /// --- Profile Information ---
            const Text('Profile Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Column(
              children: [
                UDetailRow(value: LoginController.loginUser.uId, icon: Iconsax.profile_2user2),
                const SizedBox(height: 16),
                UDetailRow(value: LoginController.loginUser.fullname, icon: Iconsax.user),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                UDetailRow(value: LoginController.loginUser.phone, icon: Iconsax.call),
                const SizedBox(height: 16),
                UDetailRow(value: LoginController.loginUser.email ?? 'No Email', icon: Iconsax.direct),
                const SizedBox(height: 16),
                UDetailRow(value: LoginController.loginUser.permanentAddress ?? 'No Address', icon: Iconsax.location),
              ],
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Add logic to show a confirmation dialog for deleting the account
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Edit Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UDetailRow extends StatelessWidget {
  const UDetailRow({
    super.key,
    this.title,
    required this.value,
    this.icon,
    this.titleStyle,
    this.valueStyle,
  });

  final String? title; // optional
  final String value; // required
  final IconData? icon; // optional
  final TextStyle? titleStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 12),
        ],
        if (title != null) Expanded(
          flex: 3,
          child: Text(
            title!,
            style: titleStyle ?? Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: valueStyle ??
                Theme.of(context).textTheme.bodyMedium?.apply(fontWeightDelta: 2),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
