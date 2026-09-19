import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/exceptions/app_exceptions.dart';
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
  final selectedVehicleIds = <String>[].obs;
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
    selectedVehicleIds.assignAll(user.assignedVehicleIds);
    selectedStatus.value = user.status;
  }

  void clearForm() {
    nameController.clear();
    phoneController.clear();
    addressController.clear();
    emailController.clear();

    selectedUserType.value = UserTypes.organization;
    selectedRoles.clear();
    selectedVehicleIds.clear();
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

  void toggleVehicleAssignment(String vehicleId) {
    if (selectedVehicleIds.contains(vehicleId)) {
      selectedVehicleIds.remove(vehicleId);
    } else {
      selectedVehicleIds.add(vehicleId);
    }
  }

  /// Admins/super-admins implicitly get every vehicle, so there's nothing
  /// for them to hand-pick; guests never operate a vehicle either.
  bool get showVehicleAssignment =>
      selectedUserType.value != UserTypes.guest &&
          !selectedRoles.contains(UserRoles.admin) &&
          !selectedRoles.contains(UserRoles.superAdmin);

  void onUserTypeChanged(String? value) {
    if (value == null) return;

    selectedUserType.value = value;

    if (value == UserTypes.guest) {
      selectedRoles.clear();
      selectedVehicleIds.clear();
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
    try {
      Authz.requirePermission(
        isEditMode.value ? Permissions.userEdit : Permissions.userCreate,
      );

      final target = editingUser;

      if (isEditMode.value && target != null) {
        Authz.requireRecordAccess(
          Authz.canEditUser(target),
          recordType: 'user',
          recordId: target.id,
        );
      }
    } on AppException catch (e) {
      _error(e.message);
      return false;
    }

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

      final roles = selectedUserType.value == UserTypes.guest
          ? <String>[]
          : selectedRoles.toList();

      final invalidRoles = roles
          .where(
            (r) => !UserRoles.isAllowedForUserType(r, selectedUserType.value),
      )
          .toList();

      if (invalidRoles.isNotEmpty) {
        _error(
          '${invalidRoles.join(', ')} not allowed for '
              '${selectedUserType.value} users.',
        );
        return false;
      }

      // Only a Super Admin may create another Super Admin.
      if (roles.contains(UserRoles.superAdmin) &&
          !LoginController.loginUser.hasRole(UserRoles.superAdmin)) {
        _error("You don't have permission to perform this action.");
        return false;
      }

      final user = UserModel(
        id: id,
        uId: uId,
        nId: '',
        fullname: name,
        phone: phone,
        email: email.isEmpty ? null : email,
        permanentAddress: address,
        assignedVehicleIds: showVehicleAssignment? selectedVehicleIds.toList() : [],
        roles: roles,
        userType: selectedUserType.value,
        status: selectedStatus.value,
        createdAt: now,
        createdBy: LoginController.loginUser.id,
      );

      await firebaseService.saveRecord(
        'users',
        id,
        user.toMap(),
      );

      await AuditService.instance.log(
        action: 'user_created',
        performedBy: LoginController.loginUser.id,
        targetUserId: id,
        newValue: {'userType': user.userType, 'roles': user.roles},
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
      return true;
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('UserController createUser: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// True if a Super Admin OTHER than [excludingUserId] still exists and is
  /// active - used to block removing/deactivating the very last Super Admin
  /// (spec sections 5 & 28).
  bool _hasAnotherActiveSuperAdmin(String excludingUserId) {
    return users.any(
          (u) =>
      u.id != excludingUserId &&
          u.status.trim().toLowerCase() == 'active' &&
          u.hasRole(UserRoles.superAdmin),
    );
  }

  Future<bool> _updateUser({
    required String name,
    required String phone,
    required String address,
    required String email,
  }) async {
    final user = editingUser;
    if (user == null) return false;

    final newUserType = selectedUserType.value;
    final newRoles = newUserType == UserTypes.guest
        ? <String>[]
        : selectedRoles.toList();
    final newStatus = selectedStatus.value;

    final identityChanged =
        newUserType != user.userType || !_sameRoles(newRoles, user.roles);

    if (identityChanged) {
      final error = Authz.validateRoleChange(
        actor: LoginController.loginUser,
        targetUserId: user.id,
        newUserType: newUserType,
        newRoles: newRoles,
      );

      if (error != null) {
        _error(error);
        return false;
      }
    }

    final losingSuperAdmin =
        user.hasRole(UserRoles.superAdmin) &&
            !newRoles.contains(UserRoles.superAdmin);
    final beingDeactivated =
        user.status.trim().toLowerCase() == 'active' &&
            newStatus.trim().toLowerCase() != 'active' &&
            user.hasRole(UserRoles.superAdmin);

    if ((losingSuperAdmin || beingDeactivated) &&
        !_hasAnotherActiveSuperAdmin(user.id)) {
      _error('Cannot remove/deactivate the last Super Admin.');
      return false;
    }

    isLoading.value = true;

    try {
      final now = DateTime.now().toUtc();

      final updatedData = {
        'fullname': name,
        'phone': phone,
        'email': email.isEmpty ? null : email,
        'permanentAddress': address,
        'assignedVehicleIds': showVehicleAssignment
            ? selectedVehicleIds.toList()
            : <String>[],
        'roles': newRoles,
        'userType': newUserType,
        'status': newStatus,
        'updatedAt': now.toIso8601String(),
        'updatedBy': LoginController.loginUser.id,
      };

      await firebaseService.updateRecord(
        'users',
        user.id,
        updatedData,
      );

      if (identityChanged) {
        await AuditService.instance.log(
          action: 'user_role_changed',
          performedBy: LoginController.loginUser.id,
          targetUserId: user.id,
          oldValue: {'userType': user.userType, 'roles': user.roles},
          newValue: {'userType': newUserType, 'roles': newRoles},
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
      return true;
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('UserController updateUser: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  bool _sameRoles(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = a.toSet();
    return setA.length == b.toSet().length && setA.containsAll(b);
  }

  Future<void> deleteSelectedUsers() async {
    if (selectedUserIds.isEmpty) return;

    final currentUserId = LoginController.loginUser.id;

    if (selectedUserIds.contains(currentUserId)) {
      _error('You cannot delete the currently logged-in user.');
      return;
    }

    final ids = selectedUserIds.toList();

    try {
      Authz.requirePermission(Permissions.userDelete);

      for (final id in ids) {
        final target = users.firstWhereOrNull((user) => user.id == id);

        Authz.requireRecordAccess(
          target != null && Authz.canDeleteUser(target),
          recordType: 'user',
          recordId: id,
        );
      }
    } on AppException catch (e) {
      _error(e.message);
      return;
    }

    isLoading.value = true;

    try {
      for (final id in ids) {
        await firebaseService.deleteRecord('users', id);
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadUsers();
      clearSelection();
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('UserController deleteUsers: $e');
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