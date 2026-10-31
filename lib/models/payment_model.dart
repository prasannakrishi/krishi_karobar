import '../utils/helper/helper_method.dart';

class PaymentAllocationModel {
  final String activityId;
  final int previousDue;
  final int paidAmount;
  final int discount;
  final int remainingDue;

  const PaymentAllocationModel({
    required this.activityId,
    required this.previousDue,
    required this.paidAmount,
    this.discount = 0,
    required this.remainingDue,
  });

  factory PaymentAllocationModel.fromMap(Map<String, dynamic> map) {
    return PaymentAllocationModel(
      activityId: map['activityId']?.toString() ?? '',
      previousDue: _toInt(map['previousDue']),
      paidAmount: _toInt(map['paidAmount']),
      discount: _toInt(map['discount']),
      remainingDue: _toInt(map['remainingDue']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'previousDue': previousDue,
      'paidAmount': paidAmount,
      'discount': discount,
      'remainingDue': remainingDue,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PaymentModel {
  final String id;
  final String uId;
  final String customerId;
  final int amount;
  final int discount;
  final String paymentMethod;
  final String? referenceNo;
  final String receivedBy;
  final DateTime paidAt;
  final List<PaymentAllocationModel> allocations;
  final String? description;
  final DateTime createdAt;

  const PaymentModel({
    required this.id,
    required this.uId,
    required this.customerId,
    required this.amount,
    this.discount = 0,
    required this.paymentMethod,
    this.referenceNo,
    required this.receivedBy,
    required this.paidAt,
    required this.allocations,
    this.description,
    required this.createdAt,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    final rawAllocations = map['allocations'];

    final allocations = rawAllocations is List
        ? rawAllocations
              .whereType<Map>()
              .map(
                (item) => PaymentAllocationModel.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
        : <PaymentAllocationModel>[];

    return PaymentModel(
      id: map['id']?.toString() ?? map['guid']?.toString() ?? '',
      uId: map['uId']?.toString() ?? map['uid']?.toString() ?? '',
      customerId: map['customerId']?.toString() ?? '',
      amount: _toInt(map['amount']),
      discount: _toInt(map['discount']),
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
      referenceNo: _nullableString(map['referenceNo']),
      receivedBy: map['receivedBy']?.toString() ?? '',
      paidAt: _toDateTime(map['paidAt']) ?? DateTime.now(),
      allocations: allocations,
      description: _nullableString(map['description']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uId': uId,
      'customerId': customerId,
      'amount': amount,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'referenceNo': referenceNo,
      'receivedBy': receivedBy,
      'paidAt': paidAt.toUtc().toIso8601String(),
      'allocations': allocations.map((e) => e.toMap()).toList(),
      'description': description,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static DateTime? _toDateTime(dynamic value) {
    return toDateTime(value);
  }
}
