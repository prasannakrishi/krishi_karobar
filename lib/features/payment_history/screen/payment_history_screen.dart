import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import 'package:krishi_karobar/common/widgets/appbar.dart';

import '../controllers/payment_history_controller.dart';
import 'widgets/history_filter_form.dart';
import 'widgets/history_filter_header.dart';
import 'widgets/payment_history_list.dart';
import 'widgets/payment_history_summary.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final controller =
    Get.isRegistered<PaymentHistoryController>()
        ? Get.find<PaymentHistoryController>()
        : Get.put(PaymentHistoryController());

    return UAppScaffold(
      appBar: UAppBar(
        title: 'Payment History',
        actions: [
          Obx(
                () => HistoryFilterHeader(
              isActive: controller.hasActiveFilters,
              onTap: () {
                Get.dialog(
                  AlertDialog(
                    title: const Text('Payment Filters'),
                    content: SizedBox(
                      width: 420,
                      child: HistoryFilterForm(
                        controller: controller,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Obx(
            () {
          if (controller.isLoading.value) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: TextField(
                  onChanged: controller.setSearchQuery,
                  decoration: InputDecoration(
                    hintText:
                    'Search receipt, customer, reference...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                    controller.searchQuery.value.isEmpty
                        ? null
                        : IconButton(
                      onPressed: () {
                        controller.setSearchQuery('');
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ),
                ),
              ),
              PaymentHistorySummary(
                controller: controller,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: PaymentHistoryList(
                  controller: controller,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}