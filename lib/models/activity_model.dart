import '../utils/helper/helper_method.dart';

/// Activity lifecycle states (spec section 10).
class ActivityStatus {
  ActivityStatus._();

  static const running = 'running';
  static const paused = 'paused';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const pending = 'pending'; // legacy default, kept for old records

  static const List<String> liveStates = [running, paused];
}

class ActivityModel {
  final String id;
  final String uId;
  String customerId;
  String vehicleId;
  String serviceId;
  String? driverId;
  String supervisorId;
  // The user who pressed START on this specific activity. Only this user
  // may pause/resume/complete it (spec: "Started-By User Control"). This
  // must never be settable by anyone other than the backend/rules-enforced
  // value at creation time - see AuditService/Authz.canControlActivity.
  String? startedByUserId;
  DateTime? pauseTime;
  DateTime? resumeTime;
  DateTime startTime;
  DateTime endTime;
  int duration;
  int rate;
  int amount;
  int paidAmount;
  int dueAmount;
  String? receivedBy;
  String? monitorBy;
  DateTime? paidAt;
  String? description;
  String status;
  String? cancelledBy;
  DateTime? cancelledAt;
  String? cancellationReason;
  final String createdBy;
  final DateTime createdAt;
  DateTime updatedAt;

  ActivityModel({
    required this.id,
    required this.uId,
    required this.customerId,
    required this.vehicleId,
    required this.serviceId,
    this.driverId,
    required this.supervisorId,
    this.startedByUserId,
    this.pauseTime,
    this.resumeTime,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.rate,
    required this.amount,
    this.paidAmount = 0,
    this.dueAmount = 0,
    this.receivedBy,
    this.monitorBy,
    this.paidAt,
    this.description,
    this.status = 'pending',
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityModel.fromMap(Map<String, dynamic> map) {
    final start = toDateTime(map['startTime']) ?? DateTime.now();

    return ActivityModel(
      id: toStringValue(map['id'] ?? map['guid']),
      uId: toStringValue(map['uId'] ?? map['uid']),
      customerId: toStringValue(map['customerId'] ?? map['customer']),
      vehicleId: toStringValue(map['vehicleId'] ?? map['vehicle']),
      serviceId: toStringValue(map['serviceId'] ?? map['serviceType']),
      driverId: map['driverId']?.toString(),
      supervisorId: toStringValue(map['supervisorId']),
      startedByUserId: map['startedByUserId']?.toString(),
      pauseTime: toDateTime(map['pauseTime']),
      resumeTime: toDateTime(map['resumeTime']),
      startTime: start,
      endTime: toDateTime(map['endTime']) ?? start,
      duration: toInt(map['duration']),
      rate: toInt(map['rate']),
      amount: toInt(map['amount']),
      paidAmount: toInt(map['paidAmount']),
      dueAmount: toInt(map['dueAmount']),
      receivedBy: map['receivedBy']?.toString(),
      monitorBy: map['monitorBy']?.toString(),
      paidAt: toDateTime(map['paidAt']),
      description: map['description']?.toString(),
      status: toStringValue(map['status'], defaultValue: 'pending'),
      cancelledBy: map['cancelledBy']?.toString(),
      cancelledAt: toDateTime(map['cancelledAt']),
      cancellationReason: map['cancellationReason']?.toString(),
      createdBy: toStringValue(map['createdBy']),
      createdAt: toDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: toDateTime(map['updatedAt']) ?? DateTime.now(),
    );
  }

  factory ActivityModel.empty() {
    final now = DateTime.now();

    return ActivityModel(
      id: '',
      uId: '',
      customerId: '',
      vehicleId: '',
      serviceId: '',
      driverId: null,
      supervisorId: '',
      startedByUserId: null,
      pauseTime: null,
      resumeTime: null,
      startTime: now,
      endTime: now,
      duration: 0,
      rate: 0,
      amount: 0,
      createdBy: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// True while this activity is actively running or paused (i.e. still
  /// "live" - not yet completed/cancelled).
  bool get isLive => ActivityStatus.liveStates.contains(status);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uId': uId,
      'customerId': customerId,
      'vehicleId': vehicleId,
      'serviceId': serviceId,
      'driverId': driverId,
      'supervisorId': supervisorId,
      'startedByUserId': startedByUserId,
      'pauseTime': pauseTime?.toUtc().toIso8601String(),
      'resumeTime': resumeTime?.toUtc().toIso8601String(),
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'duration': duration,
      'rate': rate,
      'amount': amount,
      'paidAmount': paidAmount,
      'dueAmount': dueAmount,
      'receivedBy': receivedBy,
      'monitorBy': monitorBy,
      'paidAt': paidAt?.toUtc().toIso8601String(),
      'description': description,
      'status': status,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toUtc().toIso8601String(),
      'cancellationReason': cancellationReason,
      'createdBy': createdBy,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }
}