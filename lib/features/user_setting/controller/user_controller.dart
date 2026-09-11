import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import 'package:krishi_karobar/features/controllers.dart';

class UserController extends GetxController {
  static UserController get instance => Get.find<UserController>();

  final FirebaseService firebaseService = FirebaseService();
  final SequenceService sequenceService = SequenceService.instance;
  final DataCacheService cache = DataCacheService.instance;
  final Uuid uuid = const Uuid();

  final users = <UserModel>[].obs;
  final selectedUserIds = <String>{}.obs;
  final selectionMode = false.obs;
  final isLoading = false.obs;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();

  final selectedUserType = UserTypes.organization.obs;
  final selectedRoles = <String>[].obs;
  final selectedVehicleId = RxnString();
  final selectedStatus = 'active'.obs;

  final isEditMode = false.obs;
  UserModel? editingUser;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  void loadUsers() {
    users.assignAll(
      cache.getCachedRecords<UserModel>('users')
        ..removeWhere((user) => user.isSystem),
    );
  }

  List<VehicleModel> get vehicles {
    final list = cache.getCachedRecords<VehicleModel>('vehicles');
    list.sort((a, b) => a.number.compareTo(b.number));
    return list;
  }

  bool isSelected(String id) => selectedUserIds.contains(id);

  bool get hasSelection => selectedUserIds.isNotEmpty;
  bool get hasSingleSelection => selectedUserIds.length == 1;
  bool get hasMultipleSelection => selectedUserIds.length > 1;

  bool get isAllSelected =>
      users.isNotEmpty && selectedUserIds.length == users.length;

  bool get isPartiallySelected =>
      selectedUserIds.isNotEmpty && !isAllSelected;

  UserModel? get selectedUser {
    if (!hasSingleSelection) return null;
    return users.firstWhereOrNull(
          (user) => user.id == selectedUserIds.first,
    );
  }

  void selectUser(String id) {
    if (selectionMode.value) {
      toggleSelection(id);
      return;
    }

    selectedUserIds
      ..clear()
      ..add(id);
    selectedUserIds.refresh();
  }

  void startMultiSelect(String id) {
    selectionMode.value = true;
    selectedUserIds
      ..clear()
      ..add(id);
    selectedUserIds.refresh();
  }

  void toggleSelection(String id) {
    if (!selectionMode.value) return;

    if (selectedUserIds.contains(id)) {
      selectedUserIds.remove(id);
    } else {
      selectedUserIds.add(id);
    }

    selectedUserIds.refresh();

    if (selectedUserIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void toggleSelectAll() {
    if (!selectionMode.value) {
      selectionMode.value = true;
    }

    if (isAllSelected) {
      selectedUserIds.clear();
    } else {
      selectedUserIds
        ..clear()
        ..addAll(users.map((user) => user.id));
    }

    selectedUserIds.refresh();

    if (selectedUserIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void clearSelection() {
    selectedUserIds.clear();
    selectionMode.value = false;
    selectedUserIds.refresh();
  }

  void startAdd() {
    clearForm();
    isEditMode.value = false;
    editingUser = null;
  }

  void startEdit(UserModel user) {
    editingUser = user;
    isEditMode.value = true;

    nameController.text = user.fullname;
    phoneController.text = user.phone;
    addressController.text = user.permanentAddress ?? '';
    emailController.text = user.email ?? '';

    selectedUserType.value = user.userType;
    selectedRoles.assignAll(user.roles);
    selectedVehicleId.value = user.assignedVehicleId;
    selectedStatus.value = user.status;
  }

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    emailController.clear();

    selectedUserType.value = UserTypes.organization;
    selectedRoles.clear();
    selectedVehicleId.value = null;
    selectedStatus.value = 'active';

    isEditMode.value = false;
    editingUser = null;
  }

  void toggleRole(String role) {
    if (selectedRoles.contains(role)) {
      selectedRoles.remove(role);
    } else {
      selectedRoles.add(role);
    }
  }

  void onUserTypeChanged(String? value) {
    if (value == null) return;

    selectedUserType.value = value;

    if (value == UserTypes.guest) {
      selectedRoles.clear();
      selectedVehicleId.value = null;
    } else if (value != UserTypes.external) {
      selectedVehicleId.value = null;
    }
  }

  String vehicleName(String? id) {
    if (id == null || id.isEmpty) return 'Select Vehicle';

    final vehicle = cache.getCachedRecord<VehicleModel>('vehicles', id);

    return vehicle?.number.isNotEmpty == true
        ? vehicle!.number
        : 'Select Vehicle';
  }

  Future<bool> saveUser() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final address = addressController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty) {
      _error('Name is required.');
      return false;
    }
    if (phone.isEmpty) {
      _error('Phone is required.');
      return false;
    }
    if (address.isEmpty) {
      _error('Address is required.');
      return false;
    }

    return isEditMode.value
        ? _updateUser(
      name: name,
      phone: phone,
      address: address,
      email: email,
    )
        : _createUser(
      name: name,
      phone: phone,
      address: address,
      email: email,
    );
  }

  Future<bool> _createUser({
    required String name,
    required String phone,
    required String address,
    required String email,
  }) async {
    isLoading.value = true;

    try {
      final id = uuid.v4();
      final uId = await sequenceService.generateSequence('U');
      final now = DateTime.now().toUtc();

      final user = UserModel(
        id: id,
        uId: uId,
        nId: '',
        fullname: name,
        phone: phone,
        email: email.isEmpty ? null : email,
        permanentAddress: address,
        assignedVehicleId: selectedUserType.value == UserTypes.external
            ? selectedVehicleId.value
            : null,
        roles: selectedUserType.value == UserTypes.guest
            ? []
            : selectedRoles.toList(),
        userType: selectedUserType.value,
        status: selectedStatus.value,
        createdAt: now,
        createdBy: LoginController.loginUser.id,
      );

      final saved = await firebaseService.saveRecord(
        'users',
        id,
        user.toMap(),
      );

      if (!saved) {
        _error('Unable to save user.');
        return false;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
      return true;
    } catch (e) {
      _error('Unable to create user.');
      debugPrint('UserController createUser: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _updateUser({
    required String name,
    required String phone,
    required String address,
    required String email,
  }) async {
    final user = editingUser;
    if (user == null) return false;

    isLoading.value = true;

    try {
      final now = DateTime.now().toUtc();

      final updatedData = {
        'fullname': name,
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'permanentAddress': address,
        'assignedVehicleId': selectedUserType.value == UserTypes.external
            ? selectedVehicleId.value
            : null,
        'roles': selectedUserType.value == UserTypes.guest
            ? <String>[]
            : selectedRoles.toList(),
        'userType': selectedUserType.value,
        'status': selectedStatus.value,
        'updatedAt': now.toIso8601String(),
        'updatedBy': LoginController.loginUser.id,
      };

      final updated = await firebaseService.updateRecord(
        'users',
        user.id,
        updatedData,
      );

      if (!updated) {
        _error('Unable to update user.');
        return false;
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
      return true;
    } catch (e) {
      _error('Unable to update user.');
      debugPrint('UserController updateUser: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteSelectedUsers() async {
    if (selectedUserIds.isEmpty) return;

    final currentUserId = LoginController.loginUser.id;

    if (selectedUserIds.contains(currentUserId)) {
      _error('You cannot delete the currently logged-in user.');
      return;
    }

    final ids = selectedUserIds.toList();
    isLoading.value = true;

    try {
      for (final id in ids) {
        await firebaseService.deleteRecord('users', id);
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
    } finally {
      isLoading.value = false;
    }
  }

  void _error(String message) {
    Get.snackbar(
      'User',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    super.onClose();
  }
}