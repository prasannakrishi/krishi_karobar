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
  final selectedDriver = Rxn<UserModel>();

  final vehicleTypes = <String>[
    'Tractor',
    'Harvester',
  ].obs;

  final allUsers = <UserModel>[].obs;
  final vehicleOwners = <UserModel>[].obs;
  final filteredOwners = <UserModel>[].obs;
  final drivers = <UserModel>[].obs;

  // SERVICES

  final services = <ServiceModel>[].obs;
  final selectedServiceIds = <String>[].obs;

  // UI STATE

  final isSelectionOpen = false.obs;

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

    loadVehicles();
    loadDefaultVehicle();
    fetchUsers();
    fetchServices();

    vOwnerController.addListener(() {
      _onSearchOwner(vOwnerController.text);
    });
  }

  // USERS

  Future<void> fetchUsers() async {
    try {
      final users = cache.getCachedRecords<UserModel>('users');
      allUsers.assignAll(users);
      vehicleOwners.assignAll(users.where(_isVehicleOwner).toList(),
      );

      drivers.assignAll(users.where(_isDriver).toList(),);
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

  bool _isDriver(UserModel user) {
    return user.roles.any((role) => role.trim().toLowerCase() == 'driver');
  }

  // OWNER SEARCH

  void _onSearchOwner(String query) {
    final search = query.trim().toLowerCase();

    if (search.length < 2) {
      filteredOwners.clear();
      return;
    }

    filteredOwners.assignAll(
      vehicleOwners.where(
            (user) {
          final name =
          user.fullname.toLowerCase();

          final phone =
          user.phone.toLowerCase();

          return name.contains(search) ||
              phone.contains(search);
        },
      ),
    );
  }

  void selectOwner(UserModel user) {
    selectedOwner.value = user;
    vOwnerController.text = user.fullname;
    filteredOwners.clear();
    warningField.value = null;
  }

  void clearOwnerSearch() {
    filteredOwners.clear();
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

  // INITIALIZE FORM

  void initializeVehicle(VehicleModel v) {
    selectedVehicle.value = v;

    vNumberController.text = v.number;
    vNameController.text = v.name;
    vTypeController.text = v.vehicleType;
    vModelController.text = v.model ?? '';
    vNotesController.text = v.notes ?? '';

    selectedOwner.value =
        allUsers.firstWhereOrNull(
              (user) => user.id == v.ownerId,
        );

    selectedDriver.value =
        allUsers.firstWhereOrNull(
              (user) => user.id == v.driverId,
        );

    vOwnerController.text =
        selectedOwner.value?.fullname ?? '';

    selectedServiceIds.assignAll(
      v.supportServiceIds,
    );

    warningField.value = null;
  }

  // CLEAR FORM

  void clearVehicle() {
    selectedVehicle.value = null;

    selectedOwner.value = null;
    selectedDriver.value = null;

    selectedServiceIds.clear();
    filteredOwners.clear();
    warningField.value = null;

    vNumberController.clear();
    vNameController.clear();
    vTypeController.clear();
    vOwnerController.clear();
    vModelController.clear();
    vNotesController.clear();
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
    final validationMessage =
    validateVehicle();

    if (validationMessage != null) {
      Get.snackbar(
        'Required',
        validationMessage,
        snackPosition: SnackPosition.BOTTOM,
      );

      return false;
    }

    isLoading.value = true;

    try {
      final vehicleType =
      vTypeController.text.trim();

      final sequencePrefix =
      _getVehicleSequencePrefix(
        vehicleType,
      );

      final vehicleUId =
      await sequenceService.generateSequence(
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
        supportServiceIds:
        List<String>.from(
          selectedServiceIds,
        ),
        ownerId: selectedOwner.value!.id,
        driverId: selectedDriver.value?.id,
        status: 'available',
        isActive: true,
        notes: vNotesController.text.trim().isEmpty
            ? null
            : vNotesController.text.trim(),
        createdAt: DateTime.now(),
        createdBy: LoginController.loginUser.id,
      );

      final success =
      await firebaseService.saveRecord(
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

      setDefaultVehicle(
        newVehicle,
        showMessage: false,
      );

      clearVehicle();

      Get.back();

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