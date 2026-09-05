import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';

class UPhoneHistoryDialog extends StatelessWidget {
  const UPhoneHistoryDialog({
    super.key,
    required this.phoneHistory,
    required this.onSelect,
  });

  final List<String> phoneHistory;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a Phone Number',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: UColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: phoneHistory.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final phone = phoneHistory[index];

                  return ListTile(
                    leading: const Icon(Iconsax.call),
                    title: Text(phone),
                    onTap: () {
                      onSelect(phone);
                      Get.back();
                    },
                  );
                },
              ),
            ),
            TextButton(onPressed: Get.back, child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
