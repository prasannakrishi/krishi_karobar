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
  final vehicleOwner = TextEditingController();
  final driver = TextEditingController();
  final supervisor = TextEditingController();

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
  final selectedService = Rxn<ServiceModel>();

  final filteredCustomers = <CustomerModel>[].obs;
  final filteredVehicles = <VehicleModel>[].obs;
  final filteredServices = <ServiceModel>[].obs;

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

  bool get isCustomerEmpty =>
      customerName.text.trim().isEmpty || phone.text.trim().isEmpty;

  @override
  void onInit() {
    super.onInit();
    timerController = Get.put(TimerController());
    loadDefaultVehicle();
  }
  String _userName(String? userId) {
    if (userId == null || userId.isEmpty) return '-';

    return cache.users[userId]?.fullname ?? '-';
  }
  void loadDefaultVehicle() {
    final data = storage.read('default_vehicle');

    if (data is! Map) {
      clearVehicle();
      return;
    }

    final stored = VehicleModel.fromMap(Map<String, dynamic>.from(data));

    final vehicle = cache.getCachedRecord<VehicleModel>('vehicles', stored.id);

    selectVehicle(vehicle ?? stored);
  }

  void resetForm() {
    customerName.clear();
    address.clear();
    phone.clear();
    description.clear();
    serviceType.clear();
    rate.text = '0';

    selectedCustomer.value = null;
    selectedService.value = null;

    filteredCustomers.clear();
    filteredServices.clear();

    customerCollapsed.value = false;
    loadDefaultVehicle();
  }

  void clearVehicle() {
    selectedVehicle.value = null;
    selectedService.value = null;

    vehicleNumber.clear();
    vehicleName.clear();
    vehicleOwner.clear();
    driver.clear();
    supervisor.clear();

    serviceType.clear();
    rate.text = '0';

    filteredVehicles.clear();
    filteredServices.clear();
  }

  void onSearchCustomer(String query) {
    final value = query.trim().toLowerCase();
    showCustomerSuggestions.value = value.length >= 2;
    if (value.length < 2) {
      filteredCustomers.clear();
      return;
    }
    filteredCustomers.assignAll(
      customers.where(
        (customer) =>
            customer.name.toLowerCase().contains(value) ||
            customer.phone.contains(value),
      ),
    );
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
    vehicleOwner.text = _userName(vehicle.ownerId);
    driver.text = _userName(vehicle.driverId);
    supervisor.text = _userName(vehicle.supervisorId);
    serviceType.clear();
    serviceSearch.clear();
    rate.text = '0';
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
  }

  void onCustomerChanged() {
    if (selectedCustomer.value != null) {
      selectedCustomer.value = null;
    }
  }

  void startActivity() {
    if (selectedVehicle.value == null) {
      _showMessage('Warning', 'Please select a vehicle first.');
      vehicleCollapsed.value = false;
      return;
    }

    if (selectedService.value == null) {
      _showMessage('Warning', 'Please select a service first.');
      return;
    }

    timerController.start();
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
    if (selectedVehicle.value == null) {
      _showMessage('Warning', 'Please select a vehicle.');
      return;
    }

    if (selectedService.value == null) {
      _showMessage('Warning', 'Please select a service.');
      return;
    }

    if (isCustomerEmpty && selectedCustomer.value == null) {
      customerCollapsed.value = false;
      _showMessage('Warning', 'Please enter customer details.');
      return;
    }

    if (timerController.state.value != TimerState.stopped) {
      _showMessage('Warning', 'Please stop the activity before saving.');
      return;
    }

    isLoading.value = true;

    try {
      timerController.computeAmount(_rate);

      final customer = await saveCustomer();
      final now = DateTime.now();
      final activityId = const Uuid().v4();

      final activityUId = await sequenceService.generateActivityUid(
        selectedVehicle.value!.uId,
        selectedService.value!.name,
      );

      final activity = ActivityModel(
        id: activityId,
        uId: activityUId,
        customerId: customer.id,
        vehicleId: selectedVehicle.value!.id,
        serviceId: selectedService.value!.id,
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
        _showMessage('Error', 'Failed to save activity.');
        return;
      }

      _showMessage('Success', 'Activity saved successfully.');
      timerController.reset();
      resetForm();
    } catch (error) {
      debugPrint('MonitorController: $error');
      _showMessage('Error', 'Failed to save activity.');
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

    final customer = CustomerModel(
      id: const Uuid().v4(),
      uId: await sequenceService.generateSequence('C'),
      name: customerName.text.trim(),
      phone: customerPhone,
      address: address.text.trim(),
      createdAt: now,
      createdBy: LoginController.loginUser.id,
      updatedAt: now,
      updatedBy: LoginController.loginUser.id,
    );

    final success = await firebaseService.saveRecord(
      'customers',
      customer.id,
      customer.toMap(),
    );

    if (!success) {
      throw StateError('Failed to save customer.');
    }

    selectedCustomer.value = customer;
    return customer;
  }

  double get _rate => double.tryParse(rate.text.trim()) ?? 0;

  void _showMessage(String title, String message) {
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
