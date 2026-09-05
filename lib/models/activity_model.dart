
import '../utils/helper/helper_method.dart';

class ActivityModel {
final String id;
final String uId;
String customerId;
String vehicleId;
String serviceId;
DateTime startTime;
DateTime endTime;
int duration; // seconds
double rate;
double amount;
double paidAmount;
double dueAmount;
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
startTime: start,
endTime: toDateTime(map['endTime']) ?? start,
duration: toInt(map['duration']),
rate: toDouble(map['rate']),
amount: toDouble(map['amount']),
paidAmount: toDouble(map['paidAmount']),
dueAmount: toDouble(map['dueAmount']),
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

Map<String, dynamic> toMap() {
return {
'id': id,
'uId': uId,
'customerId': customerId,
'vehicleId': vehicleId,
'serviceId': serviceId,
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