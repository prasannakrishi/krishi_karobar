import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../features/authentication/controllers/login_controllers.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/constants/enums.dart';
import 'timer_controller.dart';

class MonitorController extends GetxController {
  static MonitorController get instance => Get.find();

  final firebaseService = FirebaseService();
  final sequenceService = Get.find<SequenceService>();
  final cache = DataCacheService.instance;
  final storage = GetStorage();
  late final TimerController timerController;

  final vehicleNumber = TextEditingController();
  final vehicleName = TextEditingController();
  final vehicleType = TextEditingController();
  final vehicleOwner = TextEditingController();
  final driver = TextEditingController();
  final supervisor = TextEditingController();
  final service = TextEditingController();

  final customerName = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();

  final description = TextEditingController();
  final rate = TextEditingController(text: '0');
  final serviceType = TextEditingController();

  final vehicleCollapsed = true.obs;
  final customerCollapsed = false.obs;
  final isLoading = false.obs;

  final selectedCustomer = Rxn<CustomerModel>();
  final selectedVehicle = Rxn<VehicleModel>();
  late final selectedService = Rxn<ServiceModel>();
  final selectedDriver = Rxn<UserModel>();
  final driverWarning = false.obs;

  final filteredCustomers = <CustomerModel>[].obs;
  final filteredVehicles = <VehicleModel>[].obs;
  final filteredServices = <ServiceModel>[].obs;
  final supportedServices = <ServiceModel>[].obs;

  final vehicleSearch = TextEditingController();
  final serviceSearch = TextEditingController();

  final showCustomerSuggestions = false.obs;
  final showVehicleSuggestions = false.obs;
  final showServiceSuggestions = false.obs;

  List<CustomerModel> get customers => cache.customers.values.toList();

  List<VehicleModel> get vehicles =>
      cache.vehicles.values.where((vehicle) => vehicle.isActive).toList();

  List<ServiceModel> get services =>
      cache.services.values.where((service) => service.isActive).toList();

  bool get isLoginUserDriver => LoginController.loginUser.hasRole(UserRoles.driver);

  List<UserModel> get driversForVehicle {
    final vehicle = selectedVehicle.value;
    if (vehicle == null) return const [];

    return cache.users.values.where((user) {
      if (!user.hasRole(UserRoles.driver)) return false;
      if (user.hasAllVehicleAccess) return true;
      return user.assignedVehicleIds.contains(vehicle.id);
    }).toList();
  }

  bool get isCustomerEmpty => customerName.text.trim().isEmpty && phone.text.trim().isEmpty;

  @override
  void onInit() {
    super.onInit();
    timerController = Get.put(TimerController());
    loadDefaultVehicle();

  }
  String _userName(String? userId) {
    if (userId == null || userId.isEmpty) return '';
    return cache.users[userId]?.fullname ?? '';
  }
  void loadDefaultVehicle() {
    final data = storage.read('default_vehicle');

    if (data is! Map) {
      clearVehicle();
      return;
    }
    final vehicle = VehicleModel.fromMap(Map<String, dynamic>.from(data));
    selectVehicle(vehicle);
  }

  void resetForm() {
    customerName.clear();
    address.clear();
    phone.clear();
    description.clear();

    selectedCustomer.value = null;
    selectedService.value = null;

    filteredCustomers.clear();

    customerCollapsed.value = false;
    loadDefaultVehicle();
  }

  void clearVehicle() {
    selectedVehicle.value = null;
    selectedService.value = null;
    selectedDriver.value = null;
    driverWarning.value = false;

    vehicleNumber.clear();
    vehicleName.clear();
    vehicleOwner.clear();
    driver.clear();
    //supervisor.clear();

    serviceType.clear();
    rate.text = '0';

    filteredVehicles.clear();
    filteredServices.clear();
  }

  void onSearchCustomer(String query) {
    final value = query.trim().toLowerCase();

    if (value.length < 2) {
      filteredCustomers.clear();
      showCustomerSuggestions.value = false;
      return;
    }

    filteredCustomers.assignAll(customers.where((customer) =>
        customer.name.toLowerCase().contains(value) ||customer.phone.contains(value),
      ),
    );
    showCustomerSuggestions.value = filteredCustomers.isNotEmpty;
  }

  void onSearchVehicle(String query) {
    final value = query.trim().toLowerCase();
    showVehicleSuggestions.value = true;
    if (value.isEmpty) {
      filteredVehicles.assignAll(vehicles);
      return;
    }
    filteredVehicles.assignAll(
      vehicles.where(
        (vehicle) =>
            vehicle.number.toLowerCase().contains(value) ||
            vehicle.name.toLowerCase().contains(value),
      ),
    );
  }

  void onSearchService(String query) {
    final vehicle = selectedVehicle.value;
    if (vehicle == null) {
      filteredServices.clear();
      showServiceSuggestions.value = false;
      return;
    }
    final value = query.trim().toLowerCase();
    showServiceSuggestions.value = true;
    final supportedServices = services.where(
      (service) => vehicle.supportServiceIds.contains(service.id),
    );
    if (value.isEmpty) {
      filteredServices.assignAll(supportedServices);
      return;
    }
    filteredServices.assignAll(
      supportedServices.where(
        (service) =>
            service.name.toLowerCase().contains(value) ||
            service.description.toLowerCase().contains(value),
      ),
    );
  }

  void openVehicleSearch() {
    vehicleSearch.text = '';
    onSearchVehicle('');
  }

  void openServiceSearch() {
    serviceSearch.text = '';
    onSearchService('');
  }

  void closeCustomerSuggestions() {
    showCustomerSuggestions.value = false;
    filteredCustomers.clear();
  }

  void closeVehicleSuggestions() {
    showVehicleSuggestions.value = false;
    filteredVehicles.clear();
  }

  void closeServiceSuggestions() {
    showServiceSuggestions.value = false;
    filteredServices.clear();
  }

  void selectCustomer(CustomerModel customer) {
    selectedCustomer.value = customer;
    customerName.text = customer.name;
    address.text = customer.address;
    phone.text = customer.phone;
    closeCustomerSuggestions();
    customerCollapsed.value = true;
  }

  void selectVehicle(VehicleModel vehicle) {
    selectedVehicle.value = vehicle;
    selectedService.value = null;
    vehicleNumber.text = vehicle.number;
    vehicleName.text = vehicle.name;
    vehicleType.text = vehicle.vehicleType;
    vehicleOwner.text = _userName(vehicle.ownerId);

    driverWarning.value = false;
    if (isLoginUserDriver) {
      selectedDriver.value = LoginController.loginUser;
      driver.text = LoginController.loginUser.fullname;
    } else {
      selectedDriver.value = null;
      driver.clear();
    }

    serviceType.clear();
    serviceSearch.clear();
    rate.text = '0';

    // Populate supported services for this vehicle
    supportedServices.assignAll(
      services.where((s) => vehicle.supportServiceIds.contains(s.id)).toList(),
    );

    closeVehicleSuggestions();
    closeServiceSuggestions();
    vehicleCollapsed.value = true;
  }

  void selectService(ServiceModel service) {
    selectedService.value = service;
    serviceType.text = service.name;
    serviceSearch.text = service.name;
    rate.text = service.rate.toStringAsFixed(0);
    closeServiceSuggestions();
    // Auto-update timer controller rate if needed
    timerController.computeAmount(service.rate);
  }

  void selectDriver(UserModel user) {
    selectedDriver.value = user;
    driver.text = user.fullname;
    driverWarning.value = false;
  }

  void onCustomerChanged() {
    if (selectedCustomer.value != null) {
      selectedCustomer.value = null;
    }
  }

  void startActivity() {
    if (selectedVehicle.value == null) {
      showMessage('Warning', 'Please select a vehicle first.');
      vehicleCollapsed.value = false;
      return;
    }

    if (selectedService.value == null) {
      showMessage('Warning', 'Please select a service first.');
      return;
    }

    if (selectedDriver.value == null) {
      driverWarning.value = true;
      showMessage('Driver required', 'Please select a driver before starting the activity.');
      return;
    }

    _confirmDialog(
      title: 'Start Activity?',
      message: 'Please confirm the activity details before starting:\n\n'
          'Vehicle: ${vehicleNumber.text}\n'
          'Driver: ${selectedDriver.value?.fullname ?? '-'}\n'
          'Supervisor: ${LoginController.loginUser.fullname}\n'
          'Service: ${selectedService.value?.name ?? '-'}',
      confirmLabel: 'Start',
    ).then((confirmed) {
      if (confirmed != true) return;
      _startConfirmed();
    });
  }

  void _startConfirmed() {
    timerController.start();
    supervisor.text = LoginController.loginUser.fullname;
    _markVehicleActive();
  }

  Future<void> _markVehicleActive() async {
    final vehicle = selectedVehicle.value;
    final driverUser = selectedDriver.value;
    if (vehicle == null) return;

    vehicle.driverId = driverUser?.id;
    vehicle.supervisorId = LoginController.loginUser.id;

    await firebaseService.updateRecord('vehicles', vehicle.id, {
      'driverId': driverUser?.id,
      'supervisorId': LoginController.loginUser.id,
    });
  }

  /// Frees the vehicle up again by clearing its dynamic driver/supervisor.
  Future<void> _clearVehicleActive() async {
    final vehicle = selectedVehicle.value;
    if (vehicle == null) return;
    if (vehicle.driverId == null && vehicle.supervisorId == null) return;

    vehicle.driverId = null;
    vehicle.supervisorId = null;

    await firebaseService.updateRecord('vehicles', vehicle.id, {
      'driverId': null,
      'supervisorId': null,
    });
  }

  /// Simple Yes/No confirmation dialog. Returns true only if the user
  /// explicitly confirms - used before starting, saving, or resetting an
  /// activity so a mis-touch never silently starts/saves/wipes an activity.
  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: Text(confirmLabel),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  /// Confirms with the user before discarding the current activity data.
  Future<void> confirmReset() async {
    final confirmed = await _confirmDialog(
      title: 'Reset Activity?',
      message: 'This will discard the current activity data. Continue?',
      confirmLabel: 'Reset',
    );

    if (confirmed != true) return;

    await _clearVehicleActive();
    timerController.reset();
    resetForm();
  }

  void pauseActivity() {
    timerController.pause();
    timerController.computeAmount(_rate);
  }

  void resumeActivity() {
    timerController.resume();
  }

  void stopActivity() {
    timerController.stop();
    timerController.computeAmount(_rate);
  }

  Future<void> saveActivity() async {
    var customer = selectedCustomer.value;

    if (selectedVehicle.value == null) {
      showMessage('Warning', 'Please select a vehicle.');
      return;
    }

    if (selectedService.value == null) {
      showMessage('Warning', 'Please select a service.');
      return;
    }

    if (selectedDriver.value == null) {
      driverWarning.value = true;
      showMessage('Driver required', 'Please select a driver before saving.');
      return;
    }

    if (isCustomerEmpty && customer == null) {
      customerCollapsed.value = false;
      showMessage('Warning', 'Please enter customer details.');
      return;
    }

    if (timerController.state.value != TimerState.stopped) {
      showMessage('Warning', 'Please stop the activity before saving.');
      return;
    }

    final confirmed = await _confirmDialog(
      title: 'Save Activity?',
      message: 'Please confirm before saving:\n\n'
          'Vehicle: ${vehicleNumber.text}\n'
          'Driver: ${selectedDriver.value?.fullname ?? '-'}\n'
          'Supervisor: ${LoginController.loginUser.fullname}\n'
          'Service: ${serviceType.text}\n'
          'Amount: ${timerController.amount.value.toStringAsFixed(0)}',
      confirmLabel: 'Save',
    );

    if (confirmed != true) return;

    isLoading.value = true;

    try {
      customer ??= await saveCustomer();

      timerController.computeAmount(_rate);

      final now = DateTime.now();
      final activityId = const Uuid().v4();

      final activityUId = await sequenceService.generateActivityUid(
        serviceType: selectedService.value!.name,
        vehicleUId: selectedVehicle.value!.uId,
      );

      final activity = ActivityModel(
        id: activityId,
        uId: activityUId,
        customerId: customer.id,
        vehicleId: selectedVehicle.value!.id,
        serviceId: selectedService.value!.id,
        driverId: selectedDriver.value?.id,
        supervisorId: LoginController.loginUser.id,
        startTime: timerController.startTime ?? now,
        endTime: timerController.endTime ?? now,
        duration: timerController.durationSeconds,
        rate: _rate,
        amount: timerController.amount.value,
        paidAmount: 0,
        dueAmount: timerController.amount.value,
        receivedBy: null,
        monitorBy: LoginController.loginUser.id,
        description: description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        status: 'completed',
        createdBy: LoginController.loginUser.id,
        createdAt: now,
        updatedAt: now,
      );

      final success = await firebaseService.saveRecord(
        'activities',
        activity.id,
        activity.toMap(),
      );

      if (!success) {
        showMessage('Error', 'Failed to save activity.');
        return;
      }

      // Activity has ended - free the vehicle up again.
      await _clearVehicleActive();

      showMessage('Success', 'Activity saved successfully.');
      timerController.reset();
      resetForm();
    } catch (error) {
      debugPrint('MonitorController.saveActivity: $error');
      showMessage('Error', error.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<CustomerModel> saveCustomer() async {
    final selected = selectedCustomer.value;
    if (selected != null) return selected;

    final customerPhone = phone.text.trim();

    final existing = cache.getRecordByValue<CustomerModel>(
      'customers',
          (customer) => customer.phone.trim() == customerPhone,
    );

    if (existing != null) {
      selectedCustomer.value = existing;
      return existing;
    }

    final now = DateTime.now();
    final uId = await sequenceService.generateSequence('C');

    final duplicate = cache.getRecordByValue<CustomerModel>(
      'customers',
          (customer) => customer.uId == uId,
    );

    if (duplicate != null) {
      throw StateError(
        'Customer sequence ID "$uId" already exists.\n'
            'Name: ${duplicate.name}\n'
            'Phone: ${duplicate.phone}',
      );
    }

    final customer = CustomerModel(
      id: const Uuid().v4(),
      uId: uId,
      name: customerName.text.trim(),
      phone: customerPhone,
      address: address.text.trim(),
      createdAt: now,
      createdBy: LoginController.loginUser.id,
      updatedAt: now,
      updatedBy: LoginController.loginUser.id,
    );

    final success = await firebaseService.saveRecord('customers',customer.id,customer.toMap(),);

    if (!success) {throw StateError('Failed to save customer.');}

    selectedCustomer.value = customer;
    return customer;
  }

  double get _rate => double.tryParse(rate.text.trim()) ?? 0;

  void showMessage(String title, String message) {
    Get.snackbar(title, message);
  }

  @override
  void onClose() {
    vehicleSearch.dispose();
    serviceSearch.dispose();

    vehicleNumber.dispose();
    vehicleName.dispose();
    vehicleOwner.dispose();
    driver.dispose();
    supervisor.dispose();
    service.dispose();

    customerName.dispose();
    address.dispose();
    phone.dispose();

    description.dispose();
    rate.dispose();
    serviceType.dispose();

    if (Get.isRegistered<TimerController>()) {
      Get.delete<TimerController>();
    }

    super.onClose();
  }
}
