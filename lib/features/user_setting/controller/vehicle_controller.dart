import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';
import 'package:krishi_karobar/models/models.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/services/firebase_service.dart';
import 'package:krishi_karobar/services/sequences_service.dart';

class VehicleController extends GetxController {
  static VehicleController get instance => Get.find();
  // Veriable decleration
  final FirebaseService firebaseService = FirebaseService();
  final SequenceService sequenceService = Get.find<SequenceService>();
  final GetStorage localStorage = GetStorage();
  final Uuid uuid = const Uuid();
  final DataCacheService cache = DataCacheService.instance;

  // VEHICLE

  final selectedVehicle = Rxn<VehicleModel>();
  final vehiclesList = <VehicleModel>[].obs;
  final isLoading = false.obs;

  // USERS

  final selectedOwner = Rxn<UserModel>();

  final vehicleTypes = <String>[
    'Tractor',
    'Harvester',
  ].obs;

  final allUsers = <UserModel>[].obs;
  final vehicleOwners = <UserModel>[].obs;

  // SERVICES

  final services = <ServiceModel>[].obs;
  final selectedServiceIds = <String>[].obs;

  // UI STATE

  final isSelectionOpen = false.obs;

  // MANAGEMENT LIST SELECTION (Vehicle Management screen)

  final selectedVehicleIds = <String>{}.obs;
  final selectionMode = false.obs;

  final isEditMode = false.obs;
  VehicleModel? editingVehicle;

  // FORM

  final TextEditingController vNumberController =
  TextEditingController();

  final TextEditingController vNameController =
  TextEditingController();

  final TextEditingController vTypeController =
  TextEditingController();

  final TextEditingController vOwnerController =
  TextEditingController();

  final TextEditingController vModelController =
  TextEditingController();

  final TextEditingController vNotesController =
  TextEditingController();

  final warningField = RxnString();

  // DEFAULT VEHICLE

  static VehicleModel vehicle = VehicleModel.empty();

  @override
  void onInit() {
    super.onInit();

    loadDefaultVehicle();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await loadVehicles();
    await fetchUsers();
    await fetchServices();
    ensureDefaultVehicleForCurrentUser();
  }

  // USERS

  Future<void> fetchUsers() async {
    try {
      final users = cache.getCachedRecords<UserModel>('users');
      allUsers.assignAll(users);
      vehicleOwners.assignAll(users.where(_isVehicleOwner).toList(),
      );
    } catch (e) {
      debugPrint(
        'VehicleController: Error fetching users: $e',
      );
    }
  }

  bool _isVehicleOwner(UserModel user) {
    final type = user.userType.trim().toLowerCase();
    final roles = user.roles.map((role) => role.trim().toLowerCase());
    return type == 'admin' ||
        type == 'vehicle owner' ||
        type == 'organization' ||
        roles.contains('vehicle owner');
  }

  void selectOwner(UserModel? user) {
    selectedOwner.value = user;
    vOwnerController.text = user?.fullname ?? '';
    if (user != null) warningField.value = null;
  }

  // SERVICES

  Future<void> fetchServices() async {
    try {
      final cachedServices =
      cache.getCachedRecords<ServiceModel>(
        'services',
      );

      services.assignAll(
        cachedServices
            .where((service) => service.isActive)
            .toList(),
      );
    } catch (e) {
      debugPrint(
        'VehicleController: Error fetching services: $e',
      );
    }
  }

  bool isServiceSelected(String serviceId) {
    return selectedServiceIds.contains(serviceId);
  }

  void toggleService(String serviceId) {
    if (selectedServiceIds.contains(serviceId)) {
      selectedServiceIds.remove(serviceId);
    } else {
      selectedServiceIds.add(serviceId);
    }

    if (selectedServiceIds.isNotEmpty &&
        warningField.value == 'services') {
      warningField.value = null;
    }
  }

  void clearSelectedServices() {
    selectedServiceIds.clear();
  }

  // VEHICLES

  Future<void> loadVehicles() async {
    isLoading.value = true;

    try {
      final list =
      cache.getCachedRecords<VehicleModel>(
        'vehicles',
      );

      vehiclesList.assignAll(list);
      ensureDefaultVehicleForCurrentUser();
    } catch (e) {
      debugPrint(
        'VehicleController: Error loading vehicles: $e',
      );
    } finally {
      isLoading.value = false;
    }
  }

  // DEFAULT VEHICLE

  void loadDefaultVehicle() {
    final data =
    localStorage.read('default_vehicle');

    if (data == null) return;

    try {
      vehicle = VehicleModel.fromMap(
        Map<String, dynamic>.from(data),
      );

      selectedVehicle.value = vehicle;
    } catch (e) {
      debugPrint(
        'VehicleController: Error loading default vehicle: $e',
      );
    }
  }

  void setDefaultVehicle(
      VehicleModel v, {
        bool showMessage = true,
      }) {
    vehicle = v;
    selectedVehicle.value = v;

    localStorage.write(
      'default_vehicle',
      v.toMap(),
    );

    if (Get.isRegistered<MonitorController>()) {
      Get.find<MonitorController>().selectVehicle(v);
    }

    if (Get.isRegistered<ActivityController>()) {
      Get.find<ActivityController>().applyLocalFilters();
    }

    if (showMessage) {
      Get.snackbar(
        'Success',
        'Default Vehicle set to ${v.number}',
      );
    }
  }

  // VEHICLES ASSIGNED TO A USER (as owner or driver)

  List<VehicleModel> assignedVehiclesForUser(String userId) {
    if (userId.isEmpty) return const [];

    final user = allUsers.firstWhereOrNull((u) => u.id == LoginController.loginUser.id);

    // Organization admins/super-admins can operate any vehicle.
    if (user != null && user.hasAllVehicleAccess) {
      return vehiclesList.toList();
    }

    return vehiclesList
        .where(
          (v) =>
      v.ownerId == userId ||
          (user?.assignedVehicleIds.contains(v.id) ?? false),
    )
        .toList();
  }

  /// If the logged-in user has exactly one vehicle assigned to them
  /// (as owner or driver) and no default vehicle has been picked yet,
  /// that single vehicle automatically becomes the default.
  void ensureDefaultVehicleForCurrentUser() {
    final userId = LoginController.loginUser.id;
    if (userId.isEmpty) return;

    // Respect an already-persisted default vehicle.
    if (vehicle.id.isNotEmpty) return;

    final assigned = assignedVehiclesForUser(userId);

    if (assigned.length == 1) {
      setDefaultVehicle(assigned.first, showMessage: false);
    }
  }

  // INITIALIZE FORM

  void initializeVehicle(VehicleModel v) {
    vNumberController.text = v.number;
    vNameController.text = v.name;
    vTypeController.text = v.vehicleType;
    vModelController.text = v.model ?? '';
    vNotesController.text = v.notes ?? '';

    selectedOwner.value =
        allUsers.firstWhereOrNull(
              (user) => user.id == v.ownerId,
        );

    vOwnerController.text =
        selectedOwner.value?.fullname ?? '';

    selectedServiceIds.assignAll(
      v.supportServiceIds,
    );

    warningField.value = null;
  }

  // MANAGEMENT LIST SELECTION

  bool isRowSelected(String id) => selectedVehicleIds.contains(id);

  bool get hasSelection => selectedVehicleIds.isNotEmpty;
  bool get hasSingleSelection => selectedVehicleIds.length == 1;
  bool get hasMultipleSelection => selectedVehicleIds.length > 1;

  bool get isAllSelected =>
      vehiclesList.isNotEmpty &&
          selectedVehicleIds.length == vehiclesList.length;

  bool get isPartiallySelected =>
      selectedVehicleIds.isNotEmpty && !isAllSelected;

  VehicleModel? get selectedListVehicle {
    if (!hasSingleSelection) return null;
    return vehiclesList.firstWhereOrNull(
          (v) => v.id == selectedVehicleIds.first,
    );
  }

  void selectRow(String id) {
    if (selectionMode.value) {
      toggleSelection(id);
      return;
    }

    selectedVehicleIds
      ..clear()
      ..add(id);
    selectedVehicleIds.refresh();
  }

  void startMultiSelect(String id) {
    selectionMode.value = true;
    selectedVehicleIds
      ..clear()
      ..add(id);
    selectedVehicleIds.refresh();
  }

  void toggleSelection(String id) {
    if (!selectionMode.value) return;

    if (selectedVehicleIds.contains(id)) {
      selectedVehicleIds.remove(id);
    } else {
      selectedVehicleIds.add(id);
    }

    selectedVehicleIds.refresh();

    if (selectedVehicleIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void toggleSelectAll() {
    if (!selectionMode.value) {
      selectionMode.value = true;
    }

    if (isAllSelected) {
      selectedVehicleIds.clear();
    } else {
      selectedVehicleIds
        ..clear()
        ..addAll(vehiclesList.map((v) => v.id));
    }

    selectedVehicleIds.refresh();

    if (selectedVehicleIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void clearRowSelection() {
    selectedVehicleIds.clear();
    selectionMode.value = false;
    selectedVehicleIds.refresh();
  }

  // START ADD / EDIT (Vehicle Management form)

  void startAdd() {
    clearVehicle();
    isEditMode.value = false;
    editingVehicle = null;
  }

  void startEdit(VehicleModel v) {
    editingVehicle = v;
    isEditMode.value = true;
    initializeVehicle(v);
  }

  // CLEAR FORM

  void clearVehicle() {
    selectedOwner.value = null;

    selectedServiceIds.clear();
    warningField.value = null;

    vNumberController.clear();
    vNameController.clear();
    vTypeController.clear();
    vOwnerController.clear();
    vModelController.clear();
    vNotesController.clear();

    isEditMode.value = false;
    editingVehicle = null;
  }

  // VALIDATION

  String? validateVehicle() {
    warningField.value = null;

    if (vNumberController.text.trim().isEmpty) {
      warningField.value = 'vehicleNumber';
      return 'Vehicle number is required.';
    }

    if (vTypeController.text.trim().isEmpty) {
      warningField.value = 'vehicleType';
      return 'Vehicle type is required.';
    }

    if (vNameController.text.trim().isEmpty) {
      warningField.value = 'vehicleName';
      return 'Vehicle name is required.';
    }

    if (vModelController.text.trim().isEmpty) {
      warningField.value = 'modelYear';
      return 'Model year is required.';
    }

    if (selectedOwner.value == null) {
      warningField.value = 'owner';
      return 'Please select vehicle owner.';
    }

    if (selectedServiceIds.isEmpty) {
      warningField.value = 'services';
      return 'Please select at least one supported service.';
    }

    return null;
  }

  // VEHICLE UID

  String _getVehicleSequencePrefix(
      String vehicleType,
      ) {
    switch (vehicleType.trim().toLowerCase()) {
      case 'tractor':
        return 'VT';

      case 'harvester':
        return 'VH';

      default:
        return vehicleType
            .trim()
            .substring(0, 1)
            .toUpperCase();
    }
  }

  // SAVE VEHICLE

  Future<bool> saveVehicle() async {
    final validationMessage = validateVehicle();

    if (validationMessage != null) {
      Get.snackbar(
        'Required',
        validationMessage,
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    }

    return isEditMode.value ? _updateVehicle() : _createVehicle();
  }

  Future<bool> _createVehicle() async {
    isLoading.value = true;

    try {
      final vehicleType = vTypeController.text.trim();

      final sequencePrefix = _getVehicleSequencePrefix(
        vehicleType,
      );

      final vehicleUId = await sequenceService.generateSequence(
        sequencePrefix,
      );

      final id = uuid.v4();

      final newVehicle = VehicleModel(
        id: id,
        uId: vehicleUId,
        name: vNameController.text.trim(),
        number: vNumberController.text.trim(),
        vehicleType: vehicleType,
        model: vModelController.text.trim().isEmpty
            ? null
            : vModelController.text.trim(),
        supportServiceIds: List<String>.from(
          selectedServiceIds,
        ),
        ownerId: selectedOwner.value!.id,
        // driverId is a persistent default driver assignment. It may be
        // filled from Activity Monitor when the vehicle has no driver.
        status: 'available',
        isActive: true,
        notes: vNotesController.text.trim().isEmpty
            ? null
            : vNotesController.text.trim(),
        createdAt: DateTime.now(),
        createdBy: LoginController.loginUser.id,
      );

      final success = await firebaseService.saveRecord(
        'vehicles',
        newVehicle.id,
        newVehicle.toMap(),
      );

      if (!success) {
        Get.snackbar(
          'Error',
          'Failed to register vehicle.',
          snackPosition: SnackPosition.BOTTOM,
        );

        return false;
      }

      await loadVehicles();

      // Newly registered vehicle becomes the app-wide default vehicle.
      setDefaultVehicle(
        newVehicle,
        showMessage: false,
      );

      clearRowSelection();

      Get.snackbar(
        'Success',
        '${newVehicle.uId} - ${newVehicle.number} registered successfully.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      return true;
    } catch (e) {
      debugPrint(
        'VehicleController: Error saving vehicle: $e',
      );

      Get.snackbar(
        'Error',
        'Something went wrong while registering vehicle.',
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _updateVehicle() async {
    final target = editingVehicle;
    if (target == null) return false;

    isLoading.value = true;

    try {
      final updatedData = {
        'name': vNameController.text.trim(),
        'number': vNumberController.text.trim(),
        'vehicleType': vTypeController.text.trim(),
        'model': vModelController.text.trim().isEmpty
            ? null
            : vModelController.text.trim(),
        'supportServiceIds': List<String>.from(selectedServiceIds),
        'ownerId': selectedOwner.value!.id,
        // driverId / supervisorId are managed from Activity Monitor;
        // driverId persists while supervisorId is the current activity owner.
        'notes': vNotesController.text.trim().isEmpty
            ? null
            : vNotesController.text.trim(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'updatedBy': LoginController.loginUser.id,
      };

      final updated = await firebaseService.updateRecord(
        'vehicles',
        target.id,
        updatedData,
      );

      if (!updated) {
        Get.snackbar(
          'Error',
          'Failed to update vehicle.',
          snackPosition: SnackPosition.BOTTOM,
        );

        return false;
      }

      await loadVehicles();

      // Keep the app-wide default vehicle in sync if it was the one edited.
      if (vehicle.id == target.id) {
        final refreshed = vehiclesList.firstWhereOrNull(
              (v) => v.id == target.id,
        );

        if (refreshed != null) {
          setDefaultVehicle(refreshed, showMessage: false);
        }
      }

      clearRowSelection();

      Get.snackbar(
        'Success',
        'Vehicle updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );

      return true;
    } catch (e) {
      debugPrint(
        'VehicleController: Error updating vehicle: $e',
      );

      Get.snackbar(
        'Error',
        'Something went wrong while updating vehicle.',
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// A vehicle is "in use" if it's assigned to a user (as their vehicle),
  /// or has recorded activities against it. Such vehicles are kept out of
  /// deletion to avoid breaking those references.
  bool _isVehicleInUse(String vehicleId) {
    final assignedToUser = cache
        .getCachedRecords<UserModel>('users')
        .any((user) => user.assignedVehicleIds.contains(vehicleId));

    if (assignedToUser) return true;

    return cache
        .getCachedRecords<ActivityModel>('activities')
        .any((activity) => activity.vehicleId == vehicleId);
  }

  Future<void> deleteSelectedVehicles() async {
    if (selectedVehicleIds.isEmpty) return;

    final ids = selectedVehicleIds.toList();
    final blockedNumbers = <String>[];
    final deletableIds = <String>[];

    for (final id in ids) {
      if (_isVehicleInUse(id)) {
        final v = vehiclesList.firstWhereOrNull((vh) => vh.id == id);
        blockedNumbers.add(v?.number ?? id);
      } else {
        deletableIds.add(id);
      }
    }

    if (blockedNumbers.isNotEmpty) {
      Get.snackbar(
        'Vehicle',
        blockedNumbers.length == 1
            ? '"${blockedNumbers.first}" is assigned to a user or activity '
            'and cannot be deleted.'
            : 'These vehicles are in use and cannot be deleted: '
            '${blockedNumbers.join(', ')}.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    if (deletableIds.isEmpty) return;

    isLoading.value = true;

    try {
      for (final id in deletableIds) {
        await firebaseService.deleteRecord('vehicles', id);
      }

      await loadVehicles();
      clearRowSelection();
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    vNumberController.dispose();
    vNameController.dispose();
    vTypeController.dispose();
    vOwnerController.dispose();
    vModelController.dispose();
    vNotesController.dispose();

    super.onClose();
  }
}