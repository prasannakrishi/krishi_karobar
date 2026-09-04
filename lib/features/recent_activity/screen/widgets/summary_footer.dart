import 'package:flutter/material.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';

class SummaryFooter extends StatelessWidget {
  const SummaryFooter({
    super.key,
    required this.totalSeconds,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalDue,
    required this.controller,
  });

  final int totalSeconds;
  final int totalAmount;
  final int totalPaid;
  final int totalDue;
  final ActivityController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Duration', style: TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Amount', style: TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Paid', style: TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Due', style: TextStyle(color: Colors.teal, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            const Divider(height: 20, thickness: 1),
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.secondsToHHMMSS(totalSeconds),
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'रु $totalAmount',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'रु $totalPaid',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'रु $totalDue',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
