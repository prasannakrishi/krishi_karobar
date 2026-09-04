import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:uuid/uuid.dart';

class ActivityModel {
  final String guid;
  final String uid;
  String customer; // GUID String
  String vehicle; // GUID String
  final String startTime;
  final String endTime;
  final String duration;
  String serviceType; // GUID String
  String? receivedBy; // GUID String
  String? monitorBy; // GUID String
  final int rate;
  int amount;
  int dueAmount;
  int paidAmount;
  DateTime? paidAt;
  String? description;
  final String createdBy; // GUID String
  final DateTime createdAt;
  DateTime updatedAt;

  ActivityModel({
    required this.guid,
    required this.uid,
    required this.customer,
    required this.vehicle,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.serviceType,
    required this.rate,
    required this.amount,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.receivedBy,
    this.monitorBy,
    this.paidAt,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return 0;
    }

    return ActivityModel(
      guid: (map['guid'] ?? const Uuid().v4()).toString(),
      uid: (map['uid'] ?? '').toString(),
      customer: (map['customer'] ?? '').toString(),
      vehicle: (map['vehicle'] ?? '').toString(),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      duration: map['duration'] ?? '',
      serviceType: (map['serviceType'] ?? '').toString(),
      rate: toInt(map['rate']),
      amount: toInt(map['amount']),
      paidAmount: toInt(map['paidAmount']),
      dueAmount: toInt(map['dueAmount']),
      receivedBy: map['receivedBy']?.toString(),
      monitorBy: map['monitorBy']?.toString(),
      paidAt: map['paidAt'] != null ? DateTime.tryParse(map['paidAt']) : null,
      description: map['description'] as String?,
      createdBy: (map['createdBy'] ?? '').toString(),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory ActivityModel.empty() {
    return ActivityModel(
      guid: Uuid().v4(),
      uid: '',
      customer: '',
      vehicle: '',
      startTime: '',
      endTime: '',
      duration: '',
      serviceType: '',
      rate: 0,
      amount: 0,
      paidAmount: 0,
      dueAmount: 0,
      receivedBy: null,
      monitorBy: null,
      paidAt: null,
      description: null,
      createdBy: LoginController.loginUser.guid,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'guid': guid,
      'uid': uid,
      'customer': customer,
      'vehicle': vehicle,
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'serviceType': serviceType,
      'receivedBy': receivedBy,
      'monitorBy': monitorBy,
      'rate': rate,
      'amount': amount,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'paidAt': paidAt?.toIso8601String(),
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String()
    };
  }
}
