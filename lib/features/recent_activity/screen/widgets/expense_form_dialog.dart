import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../models/models.dart';
import '../../../../services/services.dart';
import 'package:krishi_karobar/utils/exceptions/app_exceptions.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';
import 'package:krishi_karobar/utils/helper/nepali_date_time.dart';
import '../../../authentication/controllers/login_controllers.dart';

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({super.key, this.expense});

  final ExpenseModel? expense;

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late String expenseType;
  late String categoryName;
  late TextEditingController amountController;
  late TextEditingController paidController;
  late TextEditingController descriptionController;
  late TextEditingController referenceController;
  late TextEditingController createdAtController;

  DateTime selectedCreatedAt = DateTime.now();
  String? selectedVehicleId;
  String? selectedActivityId;
  String paymentMethod = 'cash';

  final List<String> expenseTypes = ['General', 'Vehicle', 'Activity Related'];

  final Map<String, List<String>> defaultCategories = {
    'General': [
      'Office Expense',
      'Electricity',
      'Internet / Communication',
      'Stationery',
      'Rent',
      'Marketing',
      'Bank Charges',
      'Tax / Government Fee',
      'Other General',
    ],
    'Vehicle': [
      'Fuel',
      'Lubricant / Engine Oil',
      'Repair & Maintenance',
      'Spare Parts',
      'Tyre',
      'Battery',
      'Insurance',
      'Tax / Renewal',
      'Washing / Cleaning',
      'Other Vehicle',
    ],
    'Activity Related': [
      'Labour',
      'Food / Refreshment',
      'Transportation',
      'Loading / Unloading',
      'Material',
      'Fuel',
      'Machine / Equipment',
      'Other Activity',
    ],
  };

  @override
  void initState() {
    super.initState();
    final exp = widget.expense;
    expenseType = exp?.expenseType ?? 'General';
    categoryName = exp?.categoryName ?? (defaultCategories[expenseType]?.first ?? 'Other');
    amountController = TextEditingController(text: exp?.amount.toString() ?? '');
    paidController = TextEditingController(text: exp?.paidAmount.toString() ?? '');
    descriptionController = TextEditingController(text: exp?.description ?? '');
    referenceController = TextEditingController(text: exp?.referenceNo ?? '');
    selectedVehicleId = exp?.vehicleId;
    selectedActivityId = exp?.activityId;
    paymentMethod = exp?.paymentMethod ?? 'cash';
    selectedCreatedAt = exp?.createdAt ?? DateTime.now();
    createdAtController = TextEditingController(
      text: formatNepaliDateTime(selectedCreatedAt),
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    paidController.dispose();
    descriptionController.dispose();
    referenceController.dispose();
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

  List<String> get availableCategories {
    return defaultCategories[expenseType] ?? ['Other'];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final paidAmount = int.tryParse(paidController.text.trim()) ?? 0;

    if (paidAmount > amount) {
      Get.snackbar('Error', 'Paid amount cannot exceed total amount.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final dueAmount = amount - paidAmount;
    final status = dueAmount <= 0 ? 'paid' : 'due';

    final firebaseService = FirebaseService();
    final sequenceService = Get.find<SequenceService>();
    final user = LoginController.loginUser;

    try {
      if (widget.expense == null) {
        Authz.requirePermission(Permissions.expenseCreate);
      } else {
        Authz.requirePermission(Permissions.expenseEdit);
      }

      final createdTime = selectedCreatedAt;
      final currentTime = DateTime.now();
      final id = widget.expense?.id ?? const Uuid().v4();
      final uId = widget.expense?.uId ?? await sequenceService.generateSequence('E');

      final expense = ExpenseModel(
        id: id,
        uId: uId,
        expenseType: expenseType,
        categoryId: categoryName.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
        categoryName: categoryName,
        amount: amount,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        date: createdTime,
        description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
        vehicleId: selectedVehicleId,
        activityId: selectedActivityId,
        paymentMethod: paymentMethod,
        referenceNo: referenceController.text.trim().isEmpty ? null : referenceController.text.trim(),
        status: status,
        createdAt: widget.expense?.createdAt ?? createdTime,
        createdBy: widget.expense?.createdBy ?? user.id,
        updatedAt: currentTime,
        updatedBy: user.id,
      );

      await firebaseService.saveRecord('expenses', id, expense.toMap());

      Get.back();
      Get.snackbar(
        'Success',
        widget.expense == null ? 'Expense recorded successfully.' : 'Expense updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.shade100,
      );
    } catch (e) {
      Get.snackbar('Error', AppException.messageOf(e), snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = DataCacheService.instance;
    final vehicles = cache.vehicles.values.toList();
    final activities = cache.activities.values.toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      title: Text(widget.expense == null ? 'Add Expense' : 'Edit Expense (${widget.expense!.uId})'),
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
                // Expense Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: expenseType,
                  isExpanded: true,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Expense Type'),
                  items: expenseTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        expenseType = val;
                        final cats = availableCategories;
                        if (!cats.contains(categoryName)) {
                          categoryName = cats.first;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  initialValue: availableCategories.contains(categoryName) ? categoryName : availableCategories.first,
                  isExpanded: true,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Category'),
                  items: availableCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => categoryName = val);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Amount & Paid
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(labelText: 'Total Amount (रु)', prefixText: 'रु '),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid amount' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: paidController,
                        keyboardType: TextInputType.number,
                        decoration: CustomDecoration.uInputDecoration(
                          labelText: 'Paid Amount (रु)',
                          prefixText: 'रु ',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.done_all, color: Colors.green, size: 18),
                            tooltip: 'Pay Full Amount',
                            onPressed: () {
                              paidController.text = amountController.text;
                            },
                          ),
                        ),
                        validator: (v) => v == null || int.tryParse(v) == null ? 'Invalid amount' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Vehicle selection (if vehicle or activity type)
                if (expenseType == 'Vehicle' || expenseType == 'Activity Related') ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedVehicleId != null && vehicles.any((v) => v.id == selectedVehicleId)
                        ? selectedVehicleId
                        : null,
                    isExpanded: true,
                    decoration: CustomDecoration.uInputDecoration(labelText: 'Vehicle'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Select Vehicle')),
                      ...vehicles.map((v) => DropdownMenuItem(value: v.id, child: Text(v.number))),
                    ],
                    onChanged: (val) => setState(() => selectedVehicleId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                // Activity selection (if activity related)
                if (expenseType == 'Activity Related') ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedActivityId != null && activities.any((a) => a.id == selectedActivityId)
                        ? selectedActivityId
                        : null,
                    isExpanded: true,
                    decoration: CustomDecoration.uInputDecoration(labelText: 'Activity'),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('Select Activity')),
                      ...activities.map((a) => DropdownMenuItem(value: a.id, child: Text(a.uId))),
                    ],
                    onChanged: (val) => setState(() => selectedActivityId = val),
                  ),
                  const SizedBox(height: 12),
                ],

                // Payment Method
                DropdownButtonFormField<String>(
                  initialValue: paymentMethod,
                  isExpanded: true,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Payment Method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'bankTransfer', child: Text('Bank Transfer')),
                    DropdownMenuItem(value: 'eSewa', child: Text('eSewa')),
                  ],
                  onChanged: (val) => setState(() => paymentMethod = val ?? 'cash'),
                ),
                const SizedBox(height: 12),

                if (paymentMethod != 'cash') ...[
                  TextFormField(
                    controller: referenceController,
                    decoration: CustomDecoration.uInputDecoration(labelText: 'Reference / Transaction No.'),
                  ),
                  const SizedBox(height: 12),
                ],

                // Description
                TextFormField(
                  controller: descriptionController,
                  maxLines: 1,
                  decoration: CustomDecoration.uInputDecoration(labelText: 'Description / Notes'),
                ),
                const SizedBox(height: 12),

                // Created At Date & Time Field (Nepali Date Picker)
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
          child: const Text('Save Expense'),
        ),
      ],
    );
  }
}
