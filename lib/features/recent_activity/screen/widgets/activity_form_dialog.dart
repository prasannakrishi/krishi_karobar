import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/models.dart';
import '../../../../services/services.dart';
import '../../../../offline/offline_storage.dart';
import '../../../../offline/core/workspace_scope.dart';
import '../../../../common/widgets/customer_search_field.dart';
import '../../../../common/widgets/description_autocomplete.dart';
import 'package:krishi_karobar/utils/exceptions/app_exceptions.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';
import 'package:krishi_karobar/utils/validators/validation.dart';
import 'package:krishi_karobar/utils/helper/nepali_date_time.dart';
import '../../../authentication/controllers/login_controllers.dart';
import '../../controllers/activity_controller.dart';

class ActivityFormDialog extends StatefulWidget {
  const ActivityFormDialog({super.key});

  @override
  State<ActivityFormDialog> createState() => _ActivityFormDialogState();
}

class _ActivityFormDialogState extends State<ActivityFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController customerNameController;
  late TextEditingController customerAddressController;
  late TextEditingController customerPhoneController;

  CustomerModel? selectedCustomer;
  String? selectedVehicleId;
  String? selectedServiceId;

  late TextEditingController durationMinutesController;
  late TextEditingController rateController;
  late TextEditingController amountController;
  late TextEditingController paidAmountController;
  late TextEditingController discountController;
  late TextEditingController descriptionController;
  late TextEditingController createdAtController;

  DateTime selectedCreatedAt = DateTime.now();
  bool showNewCustomerFields = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    customerNameController = TextEditingController();
    customerAddressController = TextEditingController();
    customerPhoneController = TextEditingController();

    durationMinutesController = TextEditingController(text: '');
    rateController = TextEditingController(text: '');
    amountController = TextEditingController(text: '');
    paidAmountController = TextEditingController(text: '');
    discountController = TextEditingController(text: '');
    descriptionController = TextEditingController();
    createdAtController = TextEditingController(
      text: formatNepaliDateTime(selectedCreatedAt),
    );

    _loadDefaultVehicleAndService();
  }

  @override
  void dispose() {
    customerNameController.dispose();
    customerAddressController.dispose();
    customerPhoneController.dispose();
    durationMinutesController.dispose();
    rateController.dispose();
    amountController.dispose();
    paidAmountController.dispose();
    discountController.dispose();
    descriptionController.dispose();
    createdAtController.dispose();
    super.dispose();
  }

  Future<void> _pickCreatedAt() async {
    final date = await pickNepaliDate(
      context: context,
      initialDate: selectedCreatedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedCreatedAt),
    );
    if (time == null) return;

    setState(() {
      selectedCreatedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      createdAtController.text = formatNepaliDateTime(selectedCreatedAt);
    });
  }

  List<VehicleModel> get availableVehicles {
    final user = LoginController.loginUser;
    final assignedIds = user.assignedVehicleIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toList();
    if (user.hasRole(UserRoles.admin) || user.hasRole(UserRoles.superAdmin) || user.hasRole(UserRoles.manager) || assignedIds.isEmpty) {
      return cache.vehicles.values.where((v) => v.isActive).toList();
    }
    return cache.vehicles.values.where((v) => v.isActive && assignedIds.contains(v.id)).toList();
  }

  List<ServiceModel> get supportedServices {
    if (selectedVehicleId == null) return [];
    final vehicle = cache.vehicles[selectedVehicleId];
    if (vehicle == null) return [];
    return cache.services.values
        .where((s) => vehicle.supportServiceIds.contains(s.id))
        .toList();
  }

  void _loadDefaultVehicleAndService() {
    final vehicles = availableVehicles;
    if (vehicles.isNotEmpty) {
      final defaultVehicle = vehicles.first;
      selectedVehicleId = defaultVehicle.id;

      if (defaultVehicle.serviceId != null && defaultVehicle.serviceId!.isNotEmpty) {
        final s = cache.services[defaultVehicle.serviceId];
        if (s != null && defaultVehicle.supportServiceIds.contains(s.id)) {
          selectedServiceId = s.id;
          rateController.text = s.rate.toString();
          _recalculateAmount();
        } else {
          final supported = supportedServices;
          if (supported.isNotEmpty) {
            selectedServiceId = supported.first.id;
            rateController.text = supported.first.rate.toString();
            _recalculateAmount();
          }
        }
      } else {
        final supported = supportedServices;
        if (supported.isNotEmpty) {
          selectedServiceId = supported.first.id;
          rateController.text = supported.first.rate.toString();
          _recalculateAmount();
        }
      }
    }
  }

  void _recalculateAmount() {
    final minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;
    final rate = int.tryParse(rateController.text.trim()) ?? 0;
    final calculated = ((minutes / 60.0) * rate).round();
    amountController.text = calculated.toString();
  }

  Future<CustomerModel> _resolveCustomer() async {
    if (selectedCustomer != null) return selectedCustomer!;

    final name = customerNameController.text.trim();
    final phone = customerPhoneController.text.trim();
    final address = customerAddressController.text.trim();

    if (name.isEmpty) {
      throw StateError('Please enter customer name.');
    }

    final cache = DataCacheService.instance;
    final firebaseService = FirebaseService();
    final sequenceService = Get.find<SequenceService>();

    final existing = phone.isEmpty
        ? null
        : cache.getRecordByValue<CustomerModel>(
            'customers',
            (c) => c.phone!.trim() == phone,
          );

    if (existing != null) {
      selectedCustomer = existing;
      return existing;
    }

    final createdTime = selectedCreatedAt;
    final currentTime = DateTime.now();
    final uId = await sequenceService.generateSequence('C');

    final customer = CustomerModel(
      id: const Uuid().v4(),
      uId: uId,
      name: name,
      phone: phone,
      address: address,
      createdAt: createdTime,
      createdBy: LoginController.loginUser.id,
      updatedAt: currentTime,
      updatedBy: LoginController.loginUser.id,
    );

    await firebaseService.saveRecord('customers', customer.id, customer.toMap());

    try {
      if (OfflineStorage.isAvailable) {
        final userId = LoginController.loginUser.id;
        final scope = WorkspaceScope.forCurrentEnvironment(
          ownerUserId: userId,
          authUid: FirebaseAuth.instance.currentUser?.uid ?? userId,
          vehicleId: selectedVehicleId ?? 'default',
        );
        await OfflineStorage.instance.localRecords.saveRecord(
          scope,
          entityType: 'customers',
          recordId: customer.id,
          data: customer.toMap(),
          isNew: true,
        );
      }
    } catch (e) {
      debugPrint('ActivityFormDialog offline customer save notice: $e');
    }

    cache.customers[customer.id] = customer;
    cache.customers.refresh();

    selectedCustomer = customer;
    return customer;
  }

  Future<void> _submit() async {
    if (isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    if (customerNameController.text.trim().isEmpty || selectedVehicleId == null || selectedServiceId == null) {
      Get.snackbar('Error', 'Please enter Customer Name and select Vehicle and Service.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;
    final durationSeconds = minutes * 60;
    final rate = int.tryParse(rateController.text.trim()) ?? 0;
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final paidAmount = int.tryParse(paidAmountController.text.trim()) ?? 0;
    final discount = int.tryParse(discountController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();

    if ((paidAmount + discount) > amount) {
      Get.snackbar('Error', 'Paid amount + discount cannot exceed total amount.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() {
      isLoading = true;
    });

    final dueAmount = amount - paidAmount - discount;
    final status = (paidAmount + discount) >= amount ? 'paid' : ((paidAmount + discount) > 0 ? 'partial' : 'due');

    final firebaseService = FirebaseService();
    final sequenceService = Get.find<SequenceService>();
    final user = LoginController.loginUser;

    try {
      Authz.requirePermission(Permissions.activityCreate);

      final customer = await _resolveCustomer();

      final createdTime = selectedCreatedAt;
      final currentTime = DateTime.now();
      final id = const Uuid().v4();
      final uId = await sequenceService.generateActivityUid(
        serviceType: cache.services[selectedServiceId]?.name ?? 'Activity',
        vehicleUId: cache.vehicles[selectedVehicleId]?.uId ?? 'V',
      );

      // Capture GPS location at creation time for manual activity
      ActivityLocationModel? startLoc;
      try {
        startLoc = await LocationService.instance.captureCurrentLocation();
      } catch (e) {
        debugPrint('Manual activity location capture notice: $e');
      }

      final activity = ActivityModel(
        id: id,
        uId: uId,
        customerId: customer.id,
        vehicleId: selectedVehicleId!,
        serviceId: selectedServiceId!,
        supervisorId: user.id,
        startedByUserId: user.id,
        startTime: createdTime.subtract(Duration(minutes: minutes)),
        endTime: createdTime,
        duration: durationSeconds,
        rate: rate,
        amount: amount,
        paidAmount: paidAmount,
        discountAmount: discount,
        dueAmount: dueAmount > 0 ? dueAmount : 0,
        receivedBy: paidAmount > 0 ? user.id : null,
        description: description.isEmpty ? null : description,
        status: status,
        startLocation: startLoc,
        createdBy: user.id,
        createdAt: createdTime,
        updatedAt: currentTime,
      );

      final updates = <String, dynamic>{
        'activities/$id': activity.toMap(),
      };

      String? paymentId;
      PaymentModel? payment;

      if (paidAmount > 0 || discount > 0) {
        paymentId = const Uuid().v4();
        final paymentUid = await SequenceService.instance.generateSequence('P');
        payment = PaymentModel(
          id: paymentId,
          uId: paymentUid,
          customerId: customer.id,
          amount: paidAmount,
          discount: discount,
          paymentMethod: 'cash',
          receivedBy: user.id,
          paidAt: currentTime,
          allocations: [
            PaymentAllocationModel(
              activityId: id,
              previousDue: amount,
              paidAmount: paidAmount,
              discount: discount,
              remainingDue: dueAmount > 0 ? dueAmount : 0,
            ),
          ],
          description: description.isEmpty ? null : description,
          createdAt: currentTime,
        );
        updates['payments/$paymentId'] = payment.toMap();
      }

      await firebaseService.updateRecords(updates);

      try {
        if (OfflineStorage.isAvailable) {
          final scope = WorkspaceScope.forCurrentEnvironment(
            ownerUserId: user.id,
            authUid: FirebaseAuth.instance.currentUser?.uid ?? user.id,
            vehicleId: selectedVehicleId ?? 'default',
          );
          await OfflineStorage.instance.localRecords.saveRecord(
            scope,
            entityType: 'activities',
            recordId: id,
            data: activity.toMap(),
            isNew: true,
          );

          if (paymentId != null && payment != null) {
            await OfflineStorage.instance.localRecords.saveRecord(
              scope,
              entityType: 'payments',
              recordId: paymentId,
              data: payment.toMap(),
              isNew: true,
            );
          }
        }
      } catch (e) {
        debugPrint('ActivityFormDialog offline record save notice: $e');
      }

      DataCacheService.instance.activities[id] = activity;
      DataCacheService.instance.activities.refresh();

      if (paymentId != null && payment != null) {
        DataCacheService.instance.payments[paymentId] = payment;
        DataCacheService.instance.payments.refresh();
      }

      if (Get.isRegistered<ActivityController>()) {
        Get.find<ActivityController>().applyLocalFilters();
      }

      if (startLoc != null) {
        await LocationService.instance.saveStartLocation(id, startLoc);
      }

      Get.back();
      Get.snackbar(
        'Success',
        'Activity created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      Get.snackbar('Error', AppException.messageOf(e), snackPosition: SnackPosition.BOTTOM);
    }
  }

  DataCacheService get cache => DataCacheService.instance;

  List<String> get recentDescriptions {
    final set = <String>{};
    for (final a in cache.activities.values) {
      final d = a.description?.trim();
      if (d != null && d.isNotEmpty) set.add(d);
    }
    for (final s in cache.services.values) {
      final d = s.description.trim();
      if (d.isNotEmpty) set.add(d);
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final vehicles = availableVehicles;
    final supported = supportedServices;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      titlePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      title: const Text('Add Activity Manually', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Customer Name with + icon button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CustomerSearchField(
                        nameController: customerNameController,
                        phoneController: customerPhoneController,
                        addressController: customerAddressController,
                        isCustomDecoration: true,
                        onCustomerSelected: (customer) {
                          setState(() {
                            selectedCustomer = customer;
                            showNewCustomerFields = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: showNewCustomerFields ? 'Hide Customer Details' : 'Add New Customer (Address & Phone)',
                      icon: Icon(
                        showNewCustomerFields ? Icons.remove_circle_outline : Icons.add_circle_outline,
                        color: Colors.green,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          showNewCustomerFields = !showNewCustomerFields;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Address & Phone fields (shown if + clicked or customer selected)
                if (showNewCustomerFields) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: customerAddressController,
                          textCapitalization: TextCapitalization.words,
                          decoration: CustomDecoration.uInputDecoration(labelText: 'Address'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: customerPhoneController,
                          keyboardType: TextInputType.phone,
                          validator: UValidator.validatePhoneNumber,
                          decoration: CustomDecoration.uInputDecoration(labelText: 'Phone Number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    Expanded(
                      child: vehicles.length > 1
                          ? DropdownButtonFormField<String>(
                        initialValue: selectedVehicleId,
                        isExpanded: true,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Vehicle'),
                        items: vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.number))).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedVehicleId = val;
                            if (val != null) {
                              final v = cache.vehicles[val];
                              if (v != null && v.serviceId != null) {
                                selectedServiceId = v.serviceId;
                                final s = cache.services[v.serviceId];
                                if (s != null) {
                                  rateController.text = s.rate.toString();
                                  _recalculateAmount();
                                }
                              } else {
                                selectedServiceId = null;
                              }
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      )
                          : CustomDecoration.uTextField(
                        'Vehicle',
                        vehicles.isNotEmpty ? vehicles.first.number : 'No Vehicle Assigned',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: supported.length > 1
                          ? DropdownButtonFormField<String>(
                        initialValue: supported.any((s) => s.id == selectedServiceId) ? selectedServiceId : null,
                        isExpanded: true,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Service'),
                        items: supported.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedServiceId = val;
                            if (val != null) {
                              final s = cache.services[val];
                              if (s != null) {
                                rateController.text = s.rate.toString();
                                _recalculateAmount();
                              }
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      )
                          : CustomDecoration.uTextField(
                        'Service',
                        supported.isNotEmpty ? supported.first.name : '-',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Duration & Rate
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: durationMinutesController,
                            keyboardType: TextInputType.number,
                            decoration: CustomDecoration.uInputDecoration(labelText: 'Duration (Min)'),
                            onChanged: (_) {
                              _recalculateAmount();
                              setState(() {});
                            },
                            validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: rateController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Rate (रु/Hr)', prefixText: 'रु '),
                        onChanged: (_) => _recalculateAmount(),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount, Paid Amount & Discount on the same row
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Amount', prefixText: 'रु '),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(
                          labelText: 'Paid',
                          prefixText: 'रु ',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.done_all, color: Colors.green, size: 18),
                            tooltip: 'Pay Full Amount',
                            onPressed: () {
                              paidAmountController.text = amountController.text;
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Disc', prefixText: 'रु '),
                        onChanged: (_) {
                          final amount = int.tryParse(amountController.text.trim()) ?? 0;
                          final discount = int.tryParse(discountController.text.trim()) ?? 0;
                          final newPaid = amount - discount;
                          if (newPaid >= 0) {
                            paidAmountController.text = newPaid.toString();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description with reusable DescriptionAutocomplete
                DescriptionAutocomplete(
                  controller: descriptionController,
                  recentDescriptions: recentDescriptions,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Description / Notes'),
                  maxLines: 1,
                ),
                const SizedBox(height: 12),

                // Created At Date & Time Picker
                TextFormField(
                  controller: createdAtController,
                  readOnly: true,
                  onTap: _pickCreatedAt,
                  decoration: CustomDecoration.uInputDecoration(
                    labelText: 'Created At Date & Time',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today, size: 18),
                      onPressed: _pickCreatedAt,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: Get.back,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            backgroundColor: Colors.grey,
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Save Activity'),
        ),
      ],
    );
  }
}
