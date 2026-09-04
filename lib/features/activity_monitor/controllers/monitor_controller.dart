import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/timer_controller.dart';
import 'package:krishi_karobar/models/models.dart';
import 'package:krishi_karobar/models/service_model.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/services/firebase_service.dart';
import '../../../utils/constants/enums.dart';
import '../../../models/activity_model.dart';
import '../../../models/vehicle_model.dart';

class MonitorController extends GetxController {
  static MonitorController get instance => Get.find();

  final firebaseService = FirebaseService();
  final localStorage = GetStorage();
  final timeController = Get.put(TimerController());

  final vehicleNumber = TextEditingController();
  final vehicleName = TextEditingController();
  final vehicleOwner = TextEditingController();
  final driver = TextEditingController();
  final supervisor = TextEditingController();

  final customerName = TextEditingController();
  final address = TextEditingController();
  final wadNo = TextEditingController();
  final phone = TextEditingController();

  final description = TextEditingController();
  final rate = TextEditingController(text: '0');
  final serviceType = TextEditingController();

  // Reactive states for UI tracking
  final isCustomerEmpty = true.obs;
  final isVehicleEmpty = true.obs;

  var vehicleCollapsed = true.obs; 
  var customerCollapsed = false.obs;

  var isLoading = false.obs;
  var customers = <CustomerModel>[].obs;
  var vehicles = <VehicleModel>[].obs;
  var services = <ServiceModel>[].obs;

  var selectedCustomer = Rxn<CustomerModel>();
  var selectedVehicle = Rxn<VehicleModel>();
  var selectedServiceType = Rxn<ServiceModel>();

  var filteredCustomers = <CustomerModel>[].obs;
  var filteredVehicle = <VehicleModel>[].obs;
  var filteredService = <ServiceModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    
    // Track text changes reactively
    customerName.addListener(() {
      isCustomerEmpty.value = customerName.text.trim().isEmpty;
    });
    vehicleNumber.addListener(() {
      isVehicleEmpty.value = vehicleNumber.text.trim().isEmpty;
    });

    fetchAllCustomers();
    fetchAllVehicles();
    fetchAllServices();
    loadDefaultVehicle();
  }

  void resetForm() {
    customerName.clear();
    address.clear();
    wadNo.clear();
    phone.clear();
    description.clear();
    selectedCustomer.value = null;
    vehicleCollapsed.value = false;
    customerCollapsed.value = false;
    loadDefaultVehicle(); 
  }

  void loadDefaultVehicle() {
    final data = localStorage.read('default_vehicle');
    if (data != null) {
      final v = VehicleModel.fromMap(Map<String, dynamic>.from(data));
      selectVehicle(v);
    } else {
      selectedVehicle.value = null;
      vehicleNumber.clear();
      vehicleName.clear();
      vehicleOwner.clear();
      driver.clear();
      supervisor.clear();
      isVehicleEmpty.value = true;
    }
  }

  Future<void> fetchAllCustomers() async {
    try {
      isLoading.value = true;
      final customerList = await firebaseService.getAllCustomers();
      customers.assignAll(customerList);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAllVehicles() async {
    try {
      isLoading.value = true;
      final vehicleList = await firebaseService.getAllVehicles();
      vehicles.assignAll(vehicleList);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchAllServices() async {
    try {
      isLoading.value = true;
      final serviceList = await firebaseService.getAllServices();
      services.assignAll(serviceList);
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchCustomer(String query) {
    if (query.length >= 2) {
      filteredCustomers.assignAll(
        customers.where((c) => 
          c.name.toLowerCase().contains(query.toLowerCase()) || 
          c.phone.contains(query)
        ),
      );
    } else {
      filteredCustomers.clear();
    }
  }

  void onSearchVehicle() {
    filteredVehicle.assignAll(vehicles);
  }

  void onSearchService() {
    filteredService.assignAll(services);
  }

  void selectCustomer(CustomerModel customer) {
    selectedCustomer.value = customer;
    customerName.text = customer.name;
    address.text = customer.address;
    phone.text = customer.phone;
    customerCollapsed.value = true;
    filteredCustomers.clear();
  }

  void selectVehicle(VehicleModel vehicle) {
    selectedVehicle.value = vehicle;
    vehicleNumber.text = vehicle.number;
    vehicleName.text = vehicle.name;
    vehicleOwner.text = DataCacheService.instance.getUserName(vehicle.ownerId);
    driver.text = DataCacheService.instance.getUserName(vehicle.driverId);
    supervisor.text = DataCacheService.instance.getUserName(vehicle.supervisorId);
    vehicleCollapsed.value = true;
    isVehicleEmpty.value = false;
  }

  void selectService(ServiceModel service) {
    selectedServiceType.value = service;
    serviceType.text = service.name;
    rate.text = service.rate.toString();
    filteredService.clear();
  }

  void startActivity() {
    if (isVehicleEmpty.value) {
      Get.snackbar(
        'Warning',
        'pahile user ma vehicles select garnu hos',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      );
      return;
    }
    timeController.start();
  }

  Future<void> onSavePressed() async {
    // Validation for blank customer details
    if (isCustomerEmpty.value) {
      Get.snackbar(
        'Warning',
        'कृपया ग्राहकको विवरण भर्नुहोस् (Customer details missing)',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        icon: const Icon(Icons.warning, color: Colors.white),
      );
      customerCollapsed.value = false; 
      return;
    }

    try {
      timeController.computeAmount((int.parse(rate.text)));

      final amount = int.tryParse(timeController.amountNotifier.value) ?? 0;

      if (selectedServiceType.value == null) {
        Get.snackbar('Error', 'सेवा छानिएको छैन।');
        return;
      }

      var customer = await saveCustomer();
      
      final activity = ActivityModel(
        guid: Uuid().v4(),
        uid: await firebaseService.generateActivityUid(vehicleNumber.text, selectedServiceType.value!.name),
        customer: customer.guid,
        vehicle: selectedVehicle.value!.guid,
        serviceType: selectedServiceType.value!.guid,
        startTime: timeController.startTimeNotifier.value,
        endTime: timeController.endTimeNotifier.value,
        duration: timeController.durationNotifier.value,
        rate: int.parse(rate.text),
        amount: amount,
        dueAmount: amount, 
        paidAmount: 0,
        receivedBy: null,
        createdBy: LoginController.loginUser.guid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: description.text,
        monitorBy: LoginController.loginUser.guid,
      );

      final success = await firebaseService.save(activity);

      if (success) {
        if (Get.isRegistered<ActivityController>()) {
          ActivityController.instance.activities.insert(0, activity);
        }
        Get.snackbar('Success', 'डाटा सुरक्षित गरियो।');
        timeController.reset();
        resetForm();
      } else {
        Get.snackbar('Error', 'डाटा सुरक्षित गर्न सकिएन।');
      }
    } catch (e) {
      Get.snackbar('Error', 'बचत गर्दा समस्या आयो: $e');
    }
  }

  Future<CustomerModel> saveCustomer() async {
    if (selectedCustomer.value == null) {
      // Check for duplicate by phone number in existing customers list
      final existing = customers.firstWhereOrNull(
        (c) => c.phone.trim() == phone.text.trim() && phone.text.trim().isNotEmpty
      );

      if (existing != null) {
        selectedCustomer.value = existing;
        return existing;
      }

      final guid = const Uuid().v4();
      final newCustomer = CustomerModel(
        guid: guid,
        name: customerName.text,
        address: address.text,
        phone: phone.text,
        createdAt: DateTime.now(),
        createdBy: LoginController.loginUser.guid,
      );
      await firebaseService.save(newCustomer);
      customers.add(newCustomer);
      return newCustomer;
    }
    return selectedCustomer.value!;
  }

  List<Widget> buildControlButtons(TimerState state) {
    // Touch observables to ensure Obx in MonitorScreen reacts
    isCustomerEmpty.value;
    isVehicleEmpty.value;

    if (state == TimerState.initial) {
      return [
        ElevatedButton.icon(
          label: const Text('START'),
          onPressed: startActivity,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ];
    } else if (state == TimerState.running) {
      return [
        ElevatedButton.icon(
          icon: const Icon(Icons.pause),
          label: const Text('PAUSE'),
          onPressed: () {
            timeController.pause();
            timeController.computeAmount((int.parse(rate.text)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('STOP'),
          onPressed: () {
            timeController.stop();
            timeController.computeAmount((int.parse(rate.text)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ];
    } else if (state == TimerState.paused) {
      return [
        ElevatedButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('RESUME'),
          onPressed: timeController.resume,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.stop),
          label: const Text('STOP'),
          onPressed: () {
            timeController.stop();
            timeController.computeAmount((int.parse(rate.text)));
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        ),
      ];
    } else if (state == TimerState.stopped) {
      List<Widget> buttons = [
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('SAVE & RESET'),
          onPressed: onSavePressed,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        ),
      ];

      if (isCustomerEmpty.value) {
        buttons.add(
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('RESET'),
            onPressed: () {
              timeController.reset();
              resetForm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
          ),
        );
      }
      return buttons;
    }
    return [];
  }

}
