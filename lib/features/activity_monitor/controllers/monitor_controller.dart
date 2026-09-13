import 'dart:async';

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
  late final TimerController timerController = Get.put(TimerController());

  final vehicleNumber = TextEditingController();
  final vehicleName = TextEditingController();
  final vehicleType = TextEditingController();
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
  late final selectedService = Rxn<ServiceModel>();
  final selectedDriver = Rxn<UserModel>();
  String? currentActivityId;
  final driverWarning = false.obs;
  bool _isSavingActivity = false;
  bool _saveConfirmationPending = false;
  bool _isFinalizingActivity = false;

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

  ActivityModel? get liveActivity {
    final vehicle = selectedVehicle.value;
    if (vehicle == null) return null;

    final matches = cache.activities.values
        .where((a) => a.vehicleId == vehicle.id && a.isLive)
        .toList();

    return matches.isEmpty ? null : matches.first;
  }

  bool get isController {
    final activity = liveActivity;
    if (activity == null) return true; // nothing running yet - free to start
    return Authz.canControlActivity(activity);
  }
  bool get isViewOnly => liveActivity != null && !isController;

  String startedByName(ActivityModel activity) =>
      _userName(activity.startedByUserId).isEmpty
          ? '-'
          : _userName(activity.startedByUserId);

  final Map<String, Timer> _syncTimers = {};

  /// Pushes a partial update to the live activity record (debounced per
  /// [key] so unrelated fields don't cancel each other out) so every
  /// viewer's `DataCacheService.activities` picks it up automatically -
  /// but only when THIS device is the one controlling a live activity.
  /// Silently does nothing otherwise (viewers' local edits, if any, must
  /// never leak into the shared record).
  void _debouncedSync(String key, Map<String, dynamic> data) {
    final id = currentActivityId;
    if (id == null || !isController) return;

    _syncTimers[key]?.cancel();
    _syncTimers[key] = Timer(const Duration(milliseconds: 600), () {
      firebaseService.updateRecord('activities', id, data);
    });
  }

  @override
  void onInit() {
    super.onInit();
    loadDefaultVehicle();

    // Live-sync edits made by the controller while an activity is running,
    // so every viewer sees rate/description changes without waiting for a
    // pause/resume/complete.
    rate.addListener(() => _debouncedSync('rate', {'rate': _rate}));
    description.addListener(() => _debouncedSync('description', {
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
    }));

    // THE FIX: re-check the live activity for the selected vehicle every
    // time the realtime cache changes - not just once when the vehicle was
    // first selected. Without this, if the cache hasn't finished loading
    // yet when onInit->loadDefaultVehicle->selectVehicle runs (very common
    // on a fresh app start), the live activity is missed forever and the
    // form fields never populate. This also keeps a viewer's fields synced
    // whenever the controller changes something.
    ever(cache.activities, (_) => _onActivitiesCacheChanged());
    ever(cache.vehicles, (_) => _onSelectedVehicleCacheChanged());
  }

  void _onSelectedVehicleCacheChanged() {
    final selected = selectedVehicle.value;
    if (selected == null || liveActivity != null) return;

    final latest = cache.vehicles[selected.id];
    if (latest == null) return;

    final driverChanged = latest.driverId != selected.driverId;
    final serviceChanged = latest.serviceId != selected.serviceId;
    if (!driverChanged && !serviceChanged) return;

    selectedVehicle.value = latest;

    final savedDriver = latest.driverId == null
        ? null
        : cache.users[latest.driverId];
    selectedDriver.value = savedDriver;
    driver.text = savedDriver?.fullname ?? '';

    final savedService = latest.serviceId == null
        ? null
        : cache.services[latest.serviceId];
    selectedService.value = savedService;
    serviceType.text = savedService?.name ?? '';
    serviceSearch.text = savedService?.name ?? '';
    rate.text = savedService?.rate.toStringAsFixed(0) ?? '0';
  }

  void _onActivitiesCacheChanged() {
    final vehicle = selectedVehicle.value;
    if (vehicle == null) return;

    final matches = cache.activities.values
        .where((a) => a.vehicleId == vehicle.id && a.isLive)
        .toList();
    final live = matches.isEmpty ? null : matches.first;

    if (live == null) {
      // A live record disappearing from the realtime cache means the
      // activity ended/cancelled elsewhere. Viewers must reset immediately;
      // once the record is no longer live, isController becomes true, so
      // checking !isController here would incorrectly leave viewer forms
      // stuck in the old running state.
      if (currentActivityId != null && !_isFinalizingActivity) {
        currentActivityId = null;
        timerController.reset();
        resetForm();
      }
      return;
    }

    // Bind the first time we discover it, and keep re-binding for viewers
    // so their fields stay in sync with the controller's edits. Never
    // re-bind on the controller's own device for its own activity - that
    // would restart the local ticking timer on every echoed write.
    if (currentActivityId != live.id || !isController) {
      _bindToLiveActivity(live);
    }
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

    final storedVehicle = VehicleModel.fromMap(
      Map<String, dynamic>.from(data),
    );
    final vehicle = cache.vehicles[storedVehicle.id] ?? storedVehicle;
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

    _syncCustomer();
  }

  void selectVehicle(VehicleModel vehicle) {
    final resolvedVehicle = cache.vehicles[vehicle.id] ?? vehicle;
    selectedVehicle.value = resolvedVehicle;

    vehicleNumber.text = resolvedVehicle.number;
    vehicleName.text = resolvedVehicle.name;
    vehicleType.text = resolvedVehicle.vehicleType;
    vehicleOwner.text = _userName(resolvedVehicle.ownerId);

    final savedDriver = resolvedVehicle.driverId == null
        ? null
        : cache.users[resolvedVehicle.driverId];
    selectedDriver.value = savedDriver;
    driver.text = savedDriver?.fullname ?? '';

    final savedService = resolvedVehicle.serviceId == null
        ? null
        : cache.services[resolvedVehicle.serviceId];
    selectedService.value = savedService;
    serviceType.text = savedService?.name ?? '';
    serviceSearch.text = savedService?.name ?? '';
    rate.text = savedService?.rate.toStringAsFixed(0) ?? '0';

    // Populate supported services for this vehicle. Keep a valid saved
    // service in the list even if an older vehicle record has a mismatch
    // between serviceId and supportServiceIds.
    final supported = services
        .where((s) => resolvedVehicle.supportServiceIds.contains(s.id))
        .toList();
    if (savedService != null && !supported.any((s) => s.id == savedService.id)) {
      supported.insert(0, savedService);
    }
    supportedServices.assignAll(supported);

    closeVehicleSuggestions();
    closeServiceSuggestions();
    vehicleCollapsed.value = true;

    final liveMatches = cache.activities.values
        .where((a) => a.vehicleId == resolvedVehicle.id && a.isLive)
        .toList();
    final live = liveMatches.isEmpty ? null : liveMatches.first;

    if (live != null) {
      _bindToLiveActivity(live);
      return;
    }

    currentActivityId = null;
    driverWarning.value = false;
    supervisor.clear();
    description.clear();
  }
  void _bindToLiveActivity(ActivityModel activity) {
    currentActivityId = activity.id;

    driver.text = _userName(activity.driverId);
    selectedDriver.value = cache.users[activity.driverId];
    supervisor.text = _userName(activity.supervisorId);

    final service = cache.services[activity.serviceId];
    selectedService.value = service;
    serviceType.text = service?.name ?? '';
    serviceSearch.text = service?.name ?? '';
    rate.text = activity.rate.toStringAsFixed(0);

    description.text = activity.description ?? '';

    final customer = cache.customers[activity.customerId];
    if (customer != null) {
      selectedCustomer.value = customer;
      customerName.text = customer.name;
      phone.text = customer.phone;
    }

    // Rehydrate the ticking display for EVERYONE watching this vehicle -
    // not just the controller - so Duration/Amount/Start Time populate and
    // keep updating live for view-only users too (spec section 5/22).
    // Only pause/resume/complete stay gated behind Authz.canControlActivity.
    timerController.rehydrate(
      startTime: activity.startTime,
      accumulated: Duration(seconds: activity.duration),
      runningSince: activity.status == ActivityStatus.running
          ? (activity.resumeTime ?? activity.startTime)
          : null,
    );
    timerController.computeAmount(activity.rate);
  }

  void selectService(ServiceModel service) {
    if (liveActivity != null && !isController) return;
    if (!_canUpdateVehicleAssignment) {
      showMessage('Not allowed', 'You do not have permission to update vehicle service.');
      return;
    }

    selectedService.value = service;
    serviceType.text = service.name;
    serviceSearch.text = service.name;
    rate.text = service.rate.toStringAsFixed(0);
    closeServiceSuggestions();
    timerController.computeAmount(service.rate);

    final vehicle = selectedVehicle.value;
    if (vehicle != null &&
        (vehicle.serviceId == null || vehicle.serviceId!.trim().isEmpty)) {
      vehicle.serviceId = service.id;
      storage.write('default_vehicle', vehicle.toMap());
      firebaseService.updateRecord('vehicles', vehicle.id, {
        'serviceId': service.id,
      });
    }

    _syncNow({'serviceId': service.id, 'rate': service.rate});
  }

  void selectDriver(UserModel user) {
    if (liveActivity != null && !isController) return;
    if (!_canUpdateVehicleAssignment) {
      showMessage('Not allowed', 'You do not have permission to update vehicle driver.');
      return;
    }

    selectedDriver.value = user;
    driver.text = user.fullname;
    driverWarning.value = false;

    final vehicle = selectedVehicle.value;
    if (vehicle != null && vehicle.driverId != user.id) {
      // Driver is a persistent vehicle assignment. Changing it from
      // Vehicle Info replaces the previous assignment and remains in place
      // until another driver is explicitly selected.
      vehicle.driverId = user.id;
      cache.vehicles[vehicle.id] = vehicle;
      storage.write('default_vehicle', vehicle.toMap());
      firebaseService.updateRecord('vehicles', vehicle.id, {
        'driverId': user.id,
      });
    }

    _syncNow({'driverId': user.id});
  }

  bool get _canUpdateVehicleAssignment =>
      Authz.can(Permissions.vehicleEdit) ||
          Authz.can(Permissions.activityEdit) ||
          Authz.can(Permissions.activityStart);

  /// Same as [_debouncedSync] but fires immediately - used for discrete
  /// picks (service/driver/customer) rather than free-text typing.
  void _syncNow(Map<String, dynamic> data) {
    final id = currentActivityId;
    if (id == null || !isController) return;

    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    firebaseService.updateRecord('activities', id, data);
  }

  /// Enforces: sync the customer onto the live activity ONLY when there's
  /// a resolved customer id AND the name field is actually populated;
  /// otherwise the activity's customerId is cleared back to null.
  void _syncCustomer() {
    final customer = selectedCustomer.value;
    final hasValidCustomer =
        customer != null &&
            customer.id.isNotEmpty &&
            customerName.text.trim().isNotEmpty;

    _debouncedSync('customer', {
      'customerId': hasValidCustomer ? customer.id : null,
    });
  }

  void onCustomerChanged() {
    final selected = selectedCustomer.value;
    // Only invalidate the match if the text actually diverged from the
    // selected customer's name - guards against this firing when we set
    // customerName.text programmatically (e.g. _bindToLiveActivity) right
    // after also setting selectedCustomer.value, which would otherwise
    // immediately null it back out.
    if (selected != null &&
        customerName.text.trim() != selected.name.trim()) {
      selectedCustomer.value = null;
    }
    _syncCustomer();
  }

  void startActivity() {
    if (selectedVehicle.value == null) {
      showMessage('Warning', 'Please select a vehicle first.');
      vehicleCollapsed.value = false;
      return;
    }

    if (liveActivity != null) {
      showMessage(
        'Vehicle in use',
        '${startedByName(liveActivity!)} has already started an activity '
            'on this vehicle.',
      );
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

  Future<void> _startConfirmed() async {
    if (_isSavingActivity || currentActivityId != null || liveActivity != null) {
      return;
    }

    final vehicle = selectedVehicle.value;
    final service = selectedService.value;
    if (vehicle == null || service == null) return;

    timerController.start();
    supervisor.text = LoginController.loginUser.fullname;

    final id = const Uuid().v4();
    final activityUId = await sequenceService.generateActivityUid(
      serviceType: service.name,
      vehicleUId: vehicle.uId,
    );
    final now = DateTime.now();

    final activity = ActivityModel(
      id: id,
      uId: activityUId,
      customerId: selectedCustomer.value?.id ?? '',
      vehicleId: vehicle.id,
      serviceId: service.id,
      driverId: selectedDriver.value?.id,
      supervisorId: LoginController.loginUser.id,
      // Recorded ONLY here, at creation - never updated afterward. This is
      // the "started-by" ownership that decides who can control it.
      startedByUserId: LoginController.loginUser.id,
      monitorBy: LoginController.loginUser.id,
      startTime: now,
      endTime: now,
      duration: 0,
      rate: _rate,
      amount: 0,
      status: ActivityStatus.running,
      createdBy: LoginController.loginUser.id,
      createdAt: now,
      updatedAt: now,
    );

    currentActivityId = id;
    _isSavingActivity = true;

    final saved = await firebaseService.saveRecord(
      'activities',
      id,
      activity.toMap(),
    );

    if (!saved) {
      currentActivityId = null;
      timerController.reset();
      _isSavingActivity = false;
      showMessage('Error', 'Failed to start activity.');
      return;
    }
    _isSavingActivity = false;

    await AuditService.instance.log(
      action: 'activity_started',
      performedBy: LoginController.loginUser.id,
      targetRecordId: id,
      newValue: {'status': ActivityStatus.running, 'vehicleId': vehicle.id},
    );

    await _markVehicleActive();
  }

  Future<void> _markVehicleActive() async {
    final vehicle = selectedVehicle.value;
    final driverUser = selectedDriver.value;
    if (vehicle == null) return;

    // driverId is now the vehicle's persistent default driver assignment.
    // supervisorId remains the volatile current-activity assignment.
    vehicle.driverId = driverUser?.id ?? vehicle.driverId;
    vehicle.supervisorId = LoginController.loginUser.id;

    final updates = <String, dynamic>{
      'supervisorId': LoginController.loginUser.id,
    };
    if (driverUser != null) {
      updates['driverId'] = driverUser.id;
      storage.write('default_vehicle', vehicle.toMap());
    }

    await firebaseService.updateRecord('vehicles', vehicle.id, updates);
  }

  /// Clears only the volatile activity assignment. The vehicle's persistent
  /// driverId and serviceId must survive after an activity ends.
  Future<void> _clearVehicleActive() async {
    final vehicle = selectedVehicle.value;
    if (vehicle == null || vehicle.supervisorId == null) return;

    vehicle.supervisorId = null;

    await firebaseService.updateRecord('vehicles', vehicle.id, {
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

  /// True if this device may act on the running/paused activity, showing a
  /// consistent "no permission" message otherwise (defense in depth - the
  /// UI should already hide these actions from a non-controller).
  bool _requireControl() {
    final activity = liveActivity;
    if (activity == null) return true; // no live activity - normal flow
    if (Authz.canControlActivity(activity)) return true;

    showMessage(
      'Not allowed',
      "You don't have permission to perform this action. Only "
          '${startedByName(activity)} can control this activity.',
    );
    return false;
  }

  /// Confirms with the user before discarding/cancelling the current
  /// activity. If nothing has been persisted yet (Start was never pressed)
  /// this just clears the local form; otherwise it cancels the live
  /// activity record so every viewer sees it end.
  Future<void> confirmReset() async {
    if (!_requireControl()) return;

    final hasLiveRecord = currentActivityId != null;

    final confirmed = await _confirmDialog(
      title: hasLiveRecord ? 'Cancel Activity?' : 'Reset Activity?',
      message: hasLiveRecord
          ? 'This will cancel the running activity for every viewer. '
          'Continue?'
          : 'This will discard the current activity data. Continue?',
      confirmLabel: hasLiveRecord ? 'Cancel Activity' : 'Reset',
    );

    if (confirmed != true) return;

    _isFinalizingActivity = hasLiveRecord;

    if (hasLiveRecord) {
      final id = currentActivityId!;
      await firebaseService.updateRecord('activities', id, {
        'status': ActivityStatus.cancelled,
        'cancelledBy': LoginController.loginUser.id,
        'cancelledAt': DateTime.now().toUtc().toIso8601String(),
      });

      await AuditService.instance.log(
        action: 'activity_cancelled',
        performedBy: LoginController.loginUser.id,
        targetRecordId: id,
        oldValue: {'status': ActivityStatus.running},
        newValue: {'status': ActivityStatus.cancelled},
      );
    }

    currentActivityId = null;
    await _clearVehicleActive();
    timerController.reset();
    resetForm();
    _isFinalizingActivity = false;

    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();
  }

  void pauseActivity() {
    if (!_requireControl()) return;

    timerController.pause();
    timerController.computeAmount(_rate);

    final id = currentActivityId;
    if (id == null) return;

    firebaseService.updateRecord('activities', id, {
      'status': ActivityStatus.paused,
      'pauseTime': DateTime.now().toUtc().toIso8601String(),
      'duration': timerController.durationSeconds,
      'amount': timerController.amount.value,
    });

    AuditService.instance.log(
      action: 'activity_paused',
      performedBy: LoginController.loginUser.id,
      targetRecordId: id,
      oldValue: {'status': ActivityStatus.running},
      newValue: {'status': ActivityStatus.paused},
    );
  }

  void resumeActivity() {
    if (!_requireControl()) return;

    timerController.resume();

    final id = currentActivityId;
    if (id == null) return;

    firebaseService.updateRecord('activities', id, {
      'status': ActivityStatus.running,
      'resumeTime': DateTime.now().toUtc().toIso8601String(),
    });

    AuditService.instance.log(
      action: 'activity_resumed',
      performedBy: LoginController.loginUser.id,
      targetRecordId: id,
      oldValue: {'status': ActivityStatus.paused},
      newValue: {'status': ActivityStatus.running},
    );
  }

  void stopActivity() {
    if (!_requireControl()) return;

    timerController.stop();
    timerController.computeAmount(_rate);
  }

  Future<void> saveActivity() async {
    if (_isSavingActivity || _saveConfirmationPending) return;

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

    if (!_requireControl()) return;

    final activityId = currentActivityId;
    if (activityId == null) {
      showMessage('Error', 'No active activity to save. Please start again.');
      return;
    }

    _saveConfirmationPending = true;
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
    _saveConfirmationPending = false;

    if (confirmed != true) return;

    isLoading.value = true;
    _isSavingActivity = true;
    _isFinalizingActivity = true;

    try {
      // Re-read the record before completing it. This prevents a second save
      // attempt from completing an activity that another request already
      // finalized.
      final latest = await firebaseService.getRecordById('activities', activityId);
      final latestStatus = latest?['status']?.toString();
      if (latest == null || !ActivityStatus.liveStates.contains(latestStatus)) {
        currentActivityId = null;
        timerController.reset();
        resetForm();
        showMessage('Warning', 'This activity has already been completed or cancelled.');
        return;
      }

      customer ??= await saveCustomer();

      timerController.computeAmount(_rate);

      final now = DateTime.now();

      final updatedData = {
        'customerId': customer.id,
        'driverId': selectedDriver.value?.id,
        'endTime': now.toUtc().toIso8601String(),
        'duration': timerController.durationSeconds,
        'rate': _rate,
        'amount': timerController.amount.value,
        'paidAmount': 0,
        'dueAmount': timerController.amount.value,
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'status': ActivityStatus.completed,
        'updatedAt': now.toUtc().toIso8601String(),
      };

      final success = await firebaseService.updateRecord(
        'activities',
        activityId,
        updatedData,
      );

      if (!success) {
        showMessage('Error', 'Failed to save activity.');
        return;
      }

      await AuditService.instance.log(
        action: 'activity_completed',
        performedBy: LoginController.loginUser.id,
        targetRecordId: activityId,
        oldValue: {'status': ActivityStatus.running},
        newValue: {'status': ActivityStatus.completed},
      );

      // Activity has ended - free the vehicle up again.
      await _clearVehicleActive();
      currentActivityId = null;

      showMessage('Success', 'Activity saved successfully.');
      timerController.reset();
      resetForm();
      for (final timer in _syncTimers.values) {
        timer.cancel();
      }
      _syncTimers.clear();
    } catch (error) {
      debugPrint('MonitorController.saveActivity: $error');
      showMessage('Error', error.toString());
    } finally {
      _isFinalizingActivity = false;
      _isSavingActivity = false;
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
    for (final timer in _syncTimers.values) {
      timer.cancel();
    }

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
