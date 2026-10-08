import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/models/models.dart';
import 'package:krishi_karobar/services/services.dart';
import 'package:krishi_karobar/utils/exceptions/app_exceptions.dart';

class CustomerController extends GetxController {
  static CustomerController get instance => Get.find();

  final FirebaseService firebaseService = FirebaseService();
  final SequenceService sequenceService = Get.find<SequenceService>();
  final DataCacheService cache = DataCacheService.instance;
  final Uuid uuid = const Uuid();

  final customersList = <CustomerModel>[].obs;
  final isLoading = false.obs;

  // Management List Selection
  final selectedCustomerIds = <String>{}.obs;
  final selectionMode = false.obs;

  final isEditMode = false.obs;
  CustomerModel? editingCustomer;

  // Form Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  final warningField = RxnString();

  @override
  void onInit() {
    super.onInit();
    ever(cache.customers, (_) => loadCustomers());
    loadCustomers();
  }

  void loadCustomers() {
    try {
      isLoading.value = true;
      final loaded = cache.customers.values.toList();
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      customersList.assignAll(loaded);
    } catch (e) {
      debugPrint('CustomerController.loadCustomers error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Selection Logic
  bool isRowSelected(String id) => selectedCustomerIds.contains(id);

  bool get hasSelection => selectedCustomerIds.isNotEmpty;

  bool get isAllSelected =>
      customersList.isNotEmpty &&
      selectedCustomerIds.length == customersList.length;

  bool get isPartiallySelected =>
      selectedCustomerIds.isNotEmpty &&
      selectedCustomerIds.length < customersList.length;

  CustomerModel? get selectedListCustomer {
    if (selectedCustomerIds.length != 1) return null;
    final id = selectedCustomerIds.first;
    return customersList.firstWhereOrNull((c) => c.id == id);
  }

  void toggleSelection(String id) {
    if (selectedCustomerIds.contains(id)) {
      selectedCustomerIds.remove(id);
    } else {
      selectedCustomerIds.add(id);
    }

    if (selectedCustomerIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void selectRow(String id) {
    if (selectionMode.value) {
      toggleSelection(id);
      return;
    }

    if (selectedCustomerIds.contains(id) && selectedCustomerIds.length == 1) {
      selectedCustomerIds.clear();
      return;
    }

    selectedCustomerIds.assignAll([id]);
  }

  void startMultiSelect(String id) {
    selectionMode.value = true;
    selectedCustomerIds.add(id);
  }

  void toggleSelectAll() {
    if (isAllSelected) {
      selectedCustomerIds.clear();
      selectionMode.value = false;
    } else {
      selectedCustomerIds.assignAll(customersList.map((c) => c.id));
      selectionMode.value = true;
    }
  }

  void clearSelection() {
    selectedCustomerIds.clear();
    selectionMode.value = false;
  }


  // Form Management
  void startAdd() {
    isEditMode.value = false;
    editingCustomer = null;
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    warningField.value = null;
  }

  void startEdit(CustomerModel customer) {
    isEditMode.value = true;
    editingCustomer = customer;
    nameController.text = customer.name;
    phoneController.text = customer.phone!;
    addressController.text = customer.address;
    warningField.value = null;
  }

  bool validateForm() {
    warningField.value = null;

    if (nameController.text.trim().isEmpty) {
      warningField.value = 'name';
      Get.snackbar('Error', 'Customer name is required.');
      return false;
    }

    return true;
  }

  Future<void> saveCustomer() async {
    if (!validateForm()) return;

    isLoading.value = true;
    final now = DateTime.now();
    final user = LoginController.loginUser;

    try {
      if (isEditMode.value && editingCustomer != null) {
        Authz.requirePermission(Permissions.customerEdit);

        final updatedData = {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'updatedAt': now.toUtc().toIso8601String(),
          'updatedBy': user.id,
        };

        await firebaseService.updateRecord(
          'customers',
          editingCustomer!.id,
          updatedData,
        );

        Get.back();
        Get.snackbar('Success', 'Customer updated successfully.');
      } else {
        Authz.requirePermission(Permissions.customerCreate);

        final uId = await sequenceService.generateSequence('C');
        final id = uuid.v4();

        final customer = CustomerModel(
          id: id,
          uId: uId,
          name: nameController.text.trim(),
          phone: phoneController.text.trim(),
          address: addressController.text.trim(),
          createdAt: now,
          createdBy: user.id,
          updatedAt: now,
          updatedBy: user.id,
        );

        await firebaseService.saveRecord('customers', id, customer.toMap());

        Get.back();
        Get.snackbar('Success', 'Customer added successfully.');
      }

      clearSelection();
      startAdd();
    } catch (e) {
      Get.snackbar('Error', AppException.messageOf(e));
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteSelectedCustomers() async {
    if (selectedCustomerIds.isEmpty) return;

    final count = selectedCustomerIds.length;
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: Text('Delete Customer${count > 1 ? 's' : ''}'),
        content: Text(
          'Are you sure you want to delete $count selected customer${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    isLoading.value = true;
    try {
      Authz.requirePermission(Permissions.customerDelete);

      for (final id in selectedCustomerIds.toList()) {
        await firebaseService.deleteRecord('customers', id);
      }

      clearSelection();
      Get.snackbar(
        'Success',
        '$count customer${count > 1 ? 's' : ''} deleted successfully.',
      );
    } catch (e) {
      Get.snackbar('Error', AppException.messageOf(e));
    } finally {
      isLoading.value = false;
    }
  }


  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.onClose();
  }
}
