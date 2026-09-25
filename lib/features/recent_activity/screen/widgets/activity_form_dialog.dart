import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/models.dart';
import '../../../../services/services.dart';
import 'package:krishi_karobar/utils/exceptions/app_exceptions.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';
import 'package:krishi_karobar/utils/validators/validation.dart';
import '../../../authentication/controllers/login_controllers.dart';

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
  late TextEditingController descriptionController;

  final filteredCustomers = <CustomerModel>[].obs;
  final showCustomerSuggestions = false.obs;
  bool showNewCustomerFields = false;

  @override
  void initState() {
    super.initState();
    customerNameController = TextEditingController();
    customerAddressController = TextEditingController();
    customerPhoneController = TextEditingController();

    durationMinutesController = TextEditingController(text: '60');
    rateController = TextEditingController(text: '500');
    amountController = TextEditingController(text: '500');
    paidAmountController = TextEditingController(text: '0');
    descriptionController = TextEditingController();

    customerNameController.addListener(_onCustomerNameChanged);
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
    descriptionController.dispose();
    super.dispose();
  }

  void _onCustomerNameChanged() {
    final query = customerNameController.text.trim().toLowerCase();
    if (query.length < 2) {
      filteredCustomers.clear();
      showCustomerSuggestions.value = false;
      return;
    }

    final cache = DataCacheService.instance;
    final matches = cache.customers.values.where((c) =>
        c.name.toLowerCase().contains(query) || c.phone.contains(query)).toList();

    filteredCustomers.assignAll(matches);
    showCustomerSuggestions.value = true;
  }

  void _selectCustomer(CustomerModel customer) {
    setState(() {
      selectedCustomer = customer;
      customerNameController.text = customer.name;
      customerAddressController.text = customer.address;
      customerPhoneController.text = customer.phone;
      showCustomerSuggestions.value = false;
      showNewCustomerFields = true;
    });
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
            (c) => c.phone.trim() == phone,
          );

    if (existing != null) {
      selectedCustomer = existing;
      return existing;
    }

    final now = DateTime.now();
    final uId = await sequenceService.generateSequence('C');

    final customer = CustomerModel(
      id: const Uuid().v4(),
      uId: uId,
      name: name,
      phone: phone,
      address: address,
      createdAt: now,
      createdBy: LoginController.loginUser.id,
      updatedAt: now,
      updatedBy: LoginController.loginUser.id,
    );

    await firebaseService.saveRecord('customers', customer.id, customer.toMap());
    selectedCustomer = customer;
    return customer;
  }

  Future<void> _submit() async {
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
    final description = descriptionController.text.trim();

    if (paidAmount > amount) {
      Get.snackbar('Error', 'Paid amount cannot exceed total amount.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dueAmount = amount - paidAmount;
    final status = paidAmount >= amount ? 'paid' : (paidAmount > 0 ? 'partial' : 'due');

    final firebaseService = FirebaseService();
    final sequenceService = Get.find<SequenceService>();
    final user = LoginController.loginUser;

    try {
      Authz.requirePermission(Permissions.activityCreate);

      final customer = await _resolveCustomer();

      final now = DateTime.now();
      final id = const Uuid().v4();
      final uId = await sequenceService.generateActivityUid(
        serviceType: cache.services[selectedServiceId]?.name ?? 'Activity',
        vehicleUId: cache.vehicles[selectedVehicleId]?.uId ?? 'V',
      );

      final activity = ActivityModel(
        id: id,
        uId: uId,
        customerId: customer.id,
        vehicleId: selectedVehicleId!,
        serviceId: selectedServiceId!,
        supervisorId: user.id,
        startedByUserId: user.id,
        startTime: now.subtract(Duration(minutes: minutes)),
        endTime: now,
        duration: durationSeconds,
        rate: rate,
        amount: amount,
        paidAmount: paidAmount,
        dueAmount: dueAmount > 0 ? dueAmount : 0,
        receivedBy: paidAmount > 0 ? user.id : null,
        description: description.isEmpty ? null : description,
        status: status,
        createdBy: user.id,
        createdAt: now,
        updatedAt: now,
      );

      await firebaseService.saveRecord('activities', id, activity.toMap());

      Get.back();
      Get.snackbar(
        'Success',
        'Activity created successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar('Error', AppException.messageOf(e), snackPosition: SnackPosition.BOTTOM);
    }
  }

  DataCacheService get cache => DataCacheService.instance;

  @override
  Widget build(BuildContext context) {
    final vehicles = cache.vehicles.values.toList();
    final services = cache.services.values.toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      title: const Row(
        children: [
          Icon(Icons.add_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Add Activity Manually'),
        ],
      ),
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
                      child: TextFormField(
                        controller: customerNameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: CustomDecoration.uInputDecoration(
                          labelText: 'Customer Name',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, size: 20),
                            onPressed: () {},
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
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
                // Customer suggestions dropdown
                Obx(() {
                  if (!showCustomerSuggestions.value || filteredCustomers.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    margin: const EdgeInsets.only(top: 2, bottom: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCustomers.length,
                        itemBuilder: (_, index) {
                          final c = filteredCustomers[index];
                          return InkWell(
                            onTap: () => _selectCustomer(c),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (c.address.isNotEmpty)
                                    Text(
                                      c.address,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
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

                // Vehicle
                DropdownButtonFormField<String>(
                  initialValue: selectedVehicleId,
                  isExpanded: true,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Vehicle'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Select Vehicle')),
                    ...vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.number))),
                  ],
                  onChanged: (val) => setState(() => selectedVehicleId = val),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Service
                DropdownButtonFormField<String>(
                  initialValue: selectedServiceId,
                  isExpanded: true,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Service'),
                  items: [
                    const DropdownMenuItem<String>(value: null, child: Text('Select Service')),
                    ...services.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      selectedServiceId = val;
                      if (val != null) {
                        final s = services.firstWhereOrNull((item) => item.id == val);
                        if (s != null) {
                          rateController.text = s.rate.toString();
                          _recalculateAmount();
                        }
                      }
                    });
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),

                // Duration & Rate
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Duration (Min)'),
                        onChanged: (_) => _recalculateAmount(),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
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

                // Amount & Paid Amount
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Amount (रु)', prefixText: 'रु '),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Paid (रु)', prefixText: 'रु '),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: descriptionController,
                  maxLines: 2,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Description / Notes'),
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
