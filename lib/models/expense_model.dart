import '../utils/helper/helper_method.dart';

class ExpenseModel {
  final String id;
  final String uId;
  final String expenseType;
  final String categoryId;
  final String categoryName;
  final int amount;
  final int paidAmount;
  final int dueAmount;
  final DateTime date;
  final String? description;
  final String? vehicleId;
  final String? activityId;
  final String paymentMethod;
  final String? referenceNo;
  final String status; // 'paid' or 'due' or 'cancelled'
  final DateTime createdAt;
  final String createdBy;
  final DateTime updatedAt;
  final String? updatedBy;

  const ExpenseModel({
    required this.id,
    required this.uId,
    required this.expenseType,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.paidAmount,
    required this.dueAmount,
    required this.date,
    this.description,
    this.vehicleId,
    this.activityId,
    required this.paymentMethod,
    this.referenceNo,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  bool get isPaid => dueAmount <= 0 || status == 'paid';

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    final amt = _toInt(map['amount']);
    final paid = _toInt(map['paidAmount']);
    final due = _toInt(map['dueAmount']);

    return ExpenseModel(
      id: map['id']?.toString() ?? map['guid']?.toString() ?? '',
      uId: map['uId']?.toString() ?? map['uid']?.toString() ?? '',
      expenseType: map['expenseType']?.toString() ?? 'General',
      categoryId: map['categoryId']?.toString() ?? '',
      categoryName: map['categoryName']?.toString() ?? '',
      amount: amt,
      paidAmount: paid,
      dueAmount: due,
      date: _toDateTime(map['date']) ?? DateTime.now(),
      description: _nullableString(map['description']),
      vehicleId: _nullableString(map['vehicleId']),
      activityId: _nullableString(map['activityId']),
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
      referenceNo: _nullableString(map['referenceNo']),
      status: map['status']?.toString() ?? (due <= 0 ? 'paid' : 'due'),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      createdBy: map['createdBy']?.toString() ?? '',
      updatedAt: _toDateTime(map['updatedAt']) ?? DateTime.now(),
      updatedBy: map['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uId': uId,
      'expenseType': expenseType,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'amount': amount,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'date': date.toUtc().toIso8601String(),
      'description': description,
      'vehicleId': vehicleId,
      'activityId': activityId,
      'paymentMethod': paymentMethod,
      'referenceNo': referenceNo,
      'status': status,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'createdBy': createdBy,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'updatedBy': updatedBy,
    };
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static DateTime? _toDateTime(dynamic value) {
    return toDateTime(value);
  }
}
