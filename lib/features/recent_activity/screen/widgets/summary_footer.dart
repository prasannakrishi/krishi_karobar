import 'package:flutter/material.dart';

import '../../controllers/activity_controller.dart';

class SummaryItem {
  final String label;
  final String value;
  final TextAlign alignment;
  final Color? textColor;

  const SummaryItem({
    required this.label,
    required this.value,
    this.alignment = TextAlign.center,
    this.textColor,
  });
}

class UnifiedSummaryCard extends StatelessWidget {
  const UnifiedSummaryCard({
    super.key,
    required this.items,
    this.backgroundColor = const Color(0xFFE8F5E9),
  });

  final List<SummaryItem> items;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    assert(
      items.length >= 3 && items.length <= 5,
      'Summary items must be between 3 and 5 columns.',
    );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 10,
        ),
        child: Column(
          children: [
            Row(
              children: items.map((item) {
                return Expanded(
                  child: Text(
                    item.label,
                    textAlign: item.alignment,
                    style: const TextStyle(
                      color: Colors.teal,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 10, thickness: 1),
            Row(
              children: items.map((item) {
                return Expanded(
                  child: Text(
                    item.value,
                    textAlign: item.alignment,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: item.textColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryFooter extends StatelessWidget {
  const SummaryFooter({
    super.key,
    required this.totalSeconds,
    required this.totalAmount,
    required this.totalDiscount,
    required this.totalPaid,
    required this.totalDue,
  });

  final int totalSeconds;
  final int totalAmount;
  final int totalPaid;
  final int totalDiscount;
  final int totalDue;

  @override
  Widget build(BuildContext context) {
    return UnifiedSummaryCard(
      items: [
        SummaryItem(
          label: 'Duration',
          value: ActivityController.instance.secondsToHHMMSS(totalSeconds),
          alignment: TextAlign.left,
        ),
        SummaryItem(
          label: 'Amount',
          value: 'रु ${totalAmount.toStringAsFixed(0)}',
          alignment: TextAlign.center,
        ),
        SummaryItem(
          label: 'Paid',
          value: 'रु ${totalPaid.toStringAsFixed(0)}',
          alignment: TextAlign.center,
        ),
        SummaryItem(
          label: 'Discount',
          value: 'रु ${totalDiscount.toStringAsFixed(0)}',
          alignment: TextAlign.center,
        ),
        SummaryItem(
          label: 'Due',
          value: 'रु ${totalDue.toStringAsFixed(0)}',
          alignment: TextAlign.right,
          textColor: Colors.red,
        ),
      ],
    );
  }
}


