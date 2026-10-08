import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../models/activity_model.dart';
import '../../../services/data_cache_service.dart';

class DashboardRecentActivityTile extends StatelessWidget {
  const DashboardRecentActivityTile({
    super.key,
    required this.activity,
  });

  final ActivityModel activity;

  Color get statusColor {
    if (activity.dueAmount > 0) return Colors.orange;
    if (activity.status == 'completed') return Colors.green;
    if (activity.status == 'running') return Colors.blue;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final color = statusColor;
    final cache = DataCacheService.instance;
    final serviceName = cache.services[activity.serviceId]?.name ?? "";
    final vehicleName = cache.vehicles[activity.vehicleId]?.name ?? "";
    final customerName = cache.customers[activity.customerId]?.name ?? "";
    final titleName = '$serviceName.$vehicleName';
    final subtitleUId = activity.uId.isNotEmpty ? '${activity.uId} - $customerName' : '';

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Iconsax.truck, size: 19, color: Color(0xFF1B5E20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleUId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  activity.status.toString().split('.').last.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'रु. ${activity.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1B5E20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
