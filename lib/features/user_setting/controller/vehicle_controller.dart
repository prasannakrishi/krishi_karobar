import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import '../../../services/firebase_service.dart';
import '../../../models/models.dart';
import '../../authentication/controllers/login_controllers.dart';


class VehicleController extends GetxController{
  static VehicleController get instance => Get.find();

  final firebaseService = FirebaseService();
  final localStorage = GetStorage();
  final uuid = const Uuid();


  var selectedVehicle = Rxn<VehicleModel>();
  var vehiclesList = <VehicleModel>[].obs;
  
  var selectedOwner = Rxn<UserModel>();
  var selectedDriver = Rxn<UserModel>();
  var selectedSupervisor = Rxn<UserModel>();

  var allUsers = <UserModel>[].obs;
  var vehicleOwners = <UserModel>[].obs;
  var filteredOwners = <UserModel>[].obs;
  var drivers = <UserModel>[].obs;
  var supervisors = <UserModel>[].obs;

  var isSelectionOpen = false.obs;
  static VehicleModel vehicle = VehicleModel.empty();
  var isLoading = false.obs;

  final TextEditingController vNumberController = TextEditingController();
  final TextEditingController vNameController = TextEditingController();
  final TextEditingController vTypeController = TextEditingController();
  final TextEditingController vOwnerController = TextEditingController();
  final TextEditingController vModelController = TextEditingController();
  @override
  void onInit() {
    super.onInit();
    loadVehicles();
    loadDefaultVehicle();
    fetchUsers();

    vOwnerController.addListener(() {
      _onSearchOwner(vOwnerController.text);
    });
  }

  Future<void> fetchUsers() async {
    try {
      final users = await firebaseService.getAllUsers();
      allUsers.assignAll(users);
      
      vehicleOwners.assignAll(users.where((u) => u.usertype == 'Vehicle Owner').toList());
      drivers.assignAll(users.where((u) => u.usertype == 'Driver').toList());
      supervisors.assignAll(users.where((u) => u.usertype == 'Supervisor').toList());
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  void _onSearchOwner(String query) {
    if (query.length >= 2) {
      filteredOwners.assignAll(
        vehicleOwners.where((u) => 
          u.name.toLowerCase().contains(query.toLowerCase()) || 
          u.phone.contains(query)
        ).toList()
      );
    } else {
      filteredOwners.clear();
    }
  }

  void selectOwner(UserModel user) {
    selectedOwner.value = user;
    vOwnerController.text = user.name;
    filteredOwners.clear();
  }

  Future<void> loadVehicles() async {
    isLoading.value = true;
    final list = await firebaseService.getAllVehicles();
    vehiclesList.assignAll(list);
    isLoading.value = false;
  }

  void loadDefaultVehicle() {
    final data = localStorage.read('default_vehicle');
    if (data != null) {
      vehicle = VehicleModel.fromMap(Map<String, dynamic>.from(data));
      selectedVehicle.value = vehicle;
    }
  }

  void setDefaultVehicle(VehicleModel v) {
    vehicle = v;
    selectedVehicle.value = v;
    localStorage.write('default_vehicle', v.toMap());
    
    // Update MonitorController if it exists to reflect changes in Monitor screen
    if (Get.isRegistered<MonitorController>()) {
      Get.find<MonitorController>().selectVehicle(v);
    }

    // Update ActivityController if it exists to reflect changes in Activity list
    if (Get.isRegistered<ActivityController>()) {
      final activityController = Get.find<ActivityController>();
      activityController.loadDefaultVehicleFromSettings();
      activityController.applyLocalFilters();
    }

    Get.snackbar('Success', 'Default Vehicle set to ${v.number}');
  }

  void initializeVehicle(VehicleModel v) {
    selectedVehicle.value = v;
    vNumberController.text = v.number;
    vNameController.text = v.name;
    vTypeController.text = v.vehicleType;
    vOwnerController.text = DataCacheService.instance.getUserName(v.ownerId);
    vModelController.text = v.model ?? '';
    selectedOwner.value = allUsers.firstWhereOrNull((u) => u.guid == v.ownerId);
    selectedDriver.value = allUsers.firstWhereOrNull((u) => u.guid == v.driverId);
    selectedSupervisor.value = allUsers.firstWhereOrNull((u) => u.guid == v.supervisorId);
  }

  void clearVehicle() {
    selectedVehicle.value = null;
    selectedOwner.value = null;
    selectedDriver.value = null;
    selectedSupervisor.value = null;
    vNumberController.clear();
    vNameController.clear();
    vTypeController.clear();
    vOwnerController.clear();
    vModelController.clear();
  }

  @override
  void onClose() {
    vNumberController.dispose();
    vNameController.dispose();
    vTypeController.dispose();
    vOwnerController.dispose();
    vModelController.dispose();
    super.onClose();
  }

  void saveVehicle() async {
    final guid = uuid.v4();
    final newVehicle = VehicleModel(
      guid: guid,
      name: vNameController.text,
      number: vNumberController.text,
      vehicleType: vTypeController.text,
      ownerId: selectedOwner.value?.guid ?? '',
      model: vModelController.text,
      driverId: selectedDriver.value?.guid,
      supervisorId: selectedSupervisor.value?.guid,
      createdAt: DateTime.now(),
      createdBy: LoginController.loginUser.guid,
    );

    final success = await firebaseService.save(newVehicle);
    if (success) {
      loadVehicles(); // Refresh list
      setDefaultVehicle(newVehicle);
      clearVehicle();
    }
  }
}


