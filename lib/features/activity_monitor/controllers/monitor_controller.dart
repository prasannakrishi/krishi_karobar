import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

import '../../../features/authentication/controllers/login_controllers.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/exceptions/app_exceptions.dart';
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
  // Drives the collapsed "CUSTOMER INFO" summary line. Obx can only track
  // Rx reads made synchronously in its own callback - it can't see
  // TextEditingController changes directly, so this is kept in sync via
  // listeners (see onInit) instead of being computed inline in the UI.
  final customerSummary = ''.obs;
  final selectedVehicle = Rxn<VehicleModel>();
  late final selectedService = Rxn<ServiceModel>();
  final selectedDriver = Rxn<UserModel>();
  String? currentActivityId;
  ActivityLocationModel? _capturedStopLocation;
  final _finalizingActivityIds = <String>{};
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
        .where((a) =>
            a.vehicleId == vehicle.id &&
            a.isLive &&
            !_finalizingActivityIds.contains(a.id))
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

  List<String> get recentDescriptions {
    final uniqueDescriptions = <String>{};

    for (final activity in cache.activities.values) {
      final desc = activity.description?.trim();
      if (desc != null && desc.isNotEmpty) {
        uniqueDescriptions.add(desc);
      }
    }

    final list = uniqueDescriptions.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  final Map<String, Timer> _syncTimers = {};

  void _debouncedSync(String key, Map<String, dynamic> data) {
    final id = currentActivityId;
    if (id == null || !isController) return;

    _syncTimers[key]?.cancel();
    _syncTimers[key] = Timer(const Duration(milliseconds: 600), () {
      _background('activities', id, data);
    });
  }

  void _background(String path, String id, Map<String, dynamic> data) {
    firebaseService.updateRecord(path, id, data).catchError((Object error) {
      debugPrint(
        'MonitorController background sync [$path/$id]: '
            '${AppException.from(error)}',
      );
      return false;
    });
  }

  @override
  void onInit() {
    super.onInit();
    loadDefaultVehicle();

    rate.addListener(() => _debouncedSync('rate', {'rate': _rate}));
    description.addListener(() => _debouncedSync('description', {
      'description': description.text.trim().isEmpty
          ? null
          : description.text.trim(),
    }));
    customerName.addListener(onCustomerChanged);
    phone.addListener(onCustomerChanged);

    customerName.addListener(_updateCustomerSummary);
    phone.addListener(_updateCustomerSummary);
    ever(selectedCustomer, (_) => _updateCustomerSummary());
    _updateCustomerSummary();

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
        .where((a) =>
            a.vehicleId == vehicle.id &&
            a.isLive &&
            !_finalizingActivityIds.contains(a.id))
        .toList();
    final live = matches.isEmpty ? null : matches.first;

    if (live == null) {
      if (currentActivityId == null) {
        return;
      }

      final cachedCurrent = cache.activities[currentActivityId!];

      if (cachedCurrent != null && !cachedCurrent.isLive && !_isFinalizingActivity) {
        currentActivityId = null;
        timerController.reset();
        resetForm();
      }

      return;
    }

    if (currentActivityId != live.id || !isController) {
      _bindToLiveActivity(live);
    }
  }

  String _userName(String? userId) {
    if (userId == null || userId.isEmpty) return '';
    return cache.users[userId]?.fullname ?? '';
  }
  void loadDefaultVehicle() {
    final user = LoginController.loginUser;

    final assignedIds = user.assignedVehicleIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    if (assignedIds.isEmpty) {
      clearVehicle();
      return;
    }

    final matchingVehicles = cache.vehicles.values.where(
          (v) => v.isActive && assignedIds.contains(v.id),
    );

    final VehicleModel? vehicle =
    matchingVehicles.isEmpty ? null : matchingVehicles.first;

    if (vehicle == null) {
      clearVehicle();
      return;
    }

    selectVehicle(vehicle);

    storage.write(
      'default_vehicle_${user.id}',
      vehicle.toMap(),
    );
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

    customerName.clear();
    phone.clear();
    address.clear();
    selectedCustomer.value = null;

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
      supportedServices.where((service) =>
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

    // THE FIX: the customer section is per-vehicle draft data, exactly
    // like driverWarning/supervisor/description above - it was just
    // missing from this reset. Without this, switching from a vehicle
    // with a live activity (or any vehicle you'd previously typed a
    // customer for) straight to a different vehicle left the OLD
    // customer's name/phone/selection sitting in the form. If the user
    // then only edited the name (or nothing at all) before starting a
    // new activity, saveCustomer() would silently reuse that stale
    // customer - either directly (still selected) or by re-matching the
    // old phone number that never got overwritten.
    customerName.clear();
    phone.clear();
    address.clear();
    selectedCustomer.value = null;
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
    if (description.text.trim().isEmpty ) {
      description.text = service.description.trim();
    }
    closeServiceSuggestions();
    timerController.computeAmount(service.rate);

    final vehicle = selectedVehicle.value;
    if (vehicle != null &&
        (vehicle.serviceId == null || vehicle.serviceId!.trim().isEmpty)) {
      vehicle.serviceId = service.id;
      storage.write('default_vehicle', vehicle.toMap());
      _background('vehicles', vehicle.id, {
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
      vehicle.driverId = user.id;
      cache.vehicles[vehicle.id] = vehicle;
      storage.write('default_vehicle', vehicle.toMap());
      _background('vehicles', vehicle.id, {
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
    _background('activities', id, data);
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
    // selected customer's name/phone - guards against this firing when we
    // set customerName.text/phone.text programmatically (e.g.
    // selectCustomer, _bindToLiveActivity) right after also setting
    // selectedCustomer.value, which would otherwise immediately null it
    // back out. Phone is checked too since saveCustomer() dedupes
    // customers by phone, not name - editing just the phone after picking
    // an existing customer must also be treated as a different customer.
    if (selected != null &&
        (customerName.text.trim() != selected.name.trim() ||
            phone.text.trim() != selected.phone.trim())) {
      selectedCustomer.value = null;
    }
    _syncCustomer();
  }

  /// Recomputes the collapsed "CUSTOMER INFO" summary line. Falls back to
  /// whatever is currently typed when no customer is selected yet, so the
  /// summary reflects a brand-new customer's details live, not just an
  /// existing one picked from suggestions.
  void _updateCustomerSummary() {
    final selected = selectedCustomer.value;
    final name = selected?.name ?? customerName.text;
    final subtitle = selected?.uId ?? phone.text;

    customerSummary.value = '${name.padRight(20)}\n$subtitle';
  }

  void startActivity() {
    if (!_requirePermission(Permissions.activityStart)) return;

    final vehicle = selectedVehicle.value;

    if (vehicle == null) {
      showMessage('Warning', 'Please select a vehicle first.');
      vehicleCollapsed.value = false;
      return;
    }

    if (!Authz.canViewVehicle(vehicle)) {
      showMessage('Not allowed', "You don't have access to this record.");
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
      if (confirmed != true)
      {return;}
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

    _isSavingActivity = true;

    // Resolve (or create) the customer BEFORE the activity is built - a
    // new customer typed into the customer section must actually be
    // persisted here, so the activity is saved against that customer's
    // real id, never a stale/previous selection. saveCustomer() already
    // returns the existing match if one was picked from suggestions.
    final customerIdsBeforeSave = cache.customers.keys.toSet();
    CustomerModel? customer;

    try {
      if (!isCustomerEmpty) {
        customer = await saveCustomer();
      }
    } catch (error) {
      _isSavingActivity = false;
      debugPrint('MonitorController.startActivity (customer): $error');
      showMessage('Error', AppException.messageOf(error));
      return;
    }

    // True only if saveCustomer() just created this record (as opposed to
    // matching an existing one) - used below to roll it back if the
    // activity itself fails to save, so a failed activity start never
    // leaves an orphan customer with nothing pointing to it.
    final customerIsNewlyCreated =
        customer != null && !customerIdsBeforeSave.contains(customer.id);

    // The activity's uId depends on a Firebase sequence transaction and can
    // fail (bad vehicle uId prefix, sequence conflict, network/permission
    // error). This must be resolved - and the record actually persisted -
    // BEFORE the visible timer starts, so a failed creation never leaves a
    // ticking timer with no backing activity.
    final id = const Uuid().v4();
    final String activityUId;

    try {
      activityUId = await sequenceService.generateActivityUid(
        serviceType: service.name,
        vehicleUId: vehicle.uId,
      );
    } catch (error) {
      _isSavingActivity = false;
      if (customerIsNewlyCreated) {
        await _rollbackNewCustomer(customer);
      }
      debugPrint('MonitorController.startActivity (sequence): $error');
      showMessage('Error', AppException.messageOf(error));
      return;
    }

    final now = DateTime.now();

    final activity = ActivityModel(
      id: id,
      uId: activityUId,
      customerId: customer?.id ?? '',
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

    try {
      await firebaseService.saveRecord(
        'activities',
        id,
        activity.toMap(),
      );
    } catch (error) {
      _isSavingActivity = false;
      if (customerIsNewlyCreated) {
        await _rollbackNewCustomer(customer);
      }
      debugPrint('MonitorController.startActivity (save): $error');
      showMessage('Error', AppException.messageOf(error));
      return;
    }

    // Only now that the activity is confirmed persisted do we commit local
    // state and start the visible timer immediately.
    currentActivityId = id;
    _isSavingActivity = false;
    supervisor.text = LoginController.loginUser.fullname;
    timerController.start();

    // Capture GPS Start Location asynchronously while activity is running.
    // The activity start / timer calculation is NOT blocked or stopped.
    _captureStartLocationInBackground(id);

    await AuditService.instance.log(
      action: 'activity_started',
      performedBy: LoginController.loginUser.id,
      targetRecordId: id,
      newValue: {'status': ActivityStatus.running, 'vehicleId': vehicle.id},
    );

    await _markVehicleActive();
  }

  void _captureStartLocationInBackground(String activityId) {
    LocationService.instance.captureStartLocationWithRetry().then((startLoc) {
      if (startLoc != null) {
        LocationService.instance.saveStartLocation(activityId, startLoc);
        final activity = cache.activities[activityId];
        if (activity != null) {
          activity.startLocation = startLoc;
          cache.activities[activityId] = activity;
          cache.activities.refresh();
        }
      }
    }).catchError((error) {
      debugPrint('MonitorController background start location notice: $error');
    });
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

    try {
      await firebaseService.updateRecord('vehicles', vehicle.id, updates);
    } catch (error) {
      debugPrint(
        'MonitorController._markVehicleActive: ${AppException.from(error)}',
      );
    }
  }

  /// Clears only the volatile activity assignment. The vehicle's persistent
  /// driverId and serviceId must survive after an activity ends.
  Future<void> _clearVehicleActive() async {
    final vehicle = selectedVehicle.value;
    if (vehicle == null || vehicle.supervisorId == null) return;

    vehicle.supervisorId = null;

    try {
      await firebaseService.updateRecord('vehicles', vehicle.id, {
        'supervisorId': null,
      });
    } catch (error) {
      debugPrint(
        'MonitorController._clearVehicleActive: ${AppException.from(error)}',
      );
    }
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
  /// Privilege guard for the activity operations. Record-level ownership is
  /// checked separately by [_requireControl].
  bool _requirePermission(String permission) {
    try {
      Authz.requirePermission(permission);
      return true;
    } on AppException catch (e) {
      showMessage('Not allowed', e.message);
      return false;
    }
  }

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
    if (currentActivityId != null &&
        !_requirePermission(Permissions.activityCancel)) {
      return;
    }
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

      try {
        await firebaseService.updateRecord('activities', id, {
          'status': ActivityStatus.cancelled,
          'cancelledBy': LoginController.loginUser.id,
          'cancelledAt': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (error) {
        _isFinalizingActivity = false;
        debugPrint('MonitorController.confirmReset: $error');
        showMessage('Error', AppException.messageOf(error));
        return;
      }

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

    _background('activities', id, {
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

    _background('activities', id, {
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

    // Track Stop Location IMMEDIATELY when Stop button is pressed
    _capturedStopLocation = null;
    LocationService.instance.captureCurrentLocation().then((stopLoc) {
      _capturedStopLocation = stopLoc;
    }).catchError((error) {
      debugPrint('MonitorController stop location capture error: $error');
    });
  }

  Future<void> saveActivity() async {
    if (_isSavingActivity || _saveConfirmationPending) return;

    var customer = selectedCustomer.value;
    final customerIdsBeforeSave = cache.customers.keys.toSet();

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

    if (!_requirePermission(Permissions.activityComplete)) return;
    if (!_requireControl()) return;

    String? activityId = currentActivityId;

    // 1. Use the currently bound live activity first.
    if (activityId == null || activityId.isEmpty) {
      final live = liveActivity;

      if (live != null && ActivityStatus.liveStates.contains(live.status)) {
        activityId = live.id;
      }
    }

    // 2. Check DataCacheService directly for the selected vehicle.
    if (activityId == null || activityId.isEmpty) {
      final vehicle = selectedVehicle.value;

      if (vehicle != null) {
        final cachedLive = cache.activities.values
            .where(
              (activity) =>
                  activity.vehicleId == vehicle.id &&
                  ActivityStatus.liveStates.contains(activity.status),
            )
            .toList();

        if (cachedLive.isNotEmpty) {
          activityId = cachedLive.first.id;
        }
      }
    }

    // 3. Final fallback: read the active activity directly from Firebase.
    if (activityId == null || activityId.isEmpty) {
      final vehicle = selectedVehicle.value;

      if (vehicle != null) {
        final cachedLive = cache.activities.values
            .where(
              (activity) =>
                  activity.vehicleId == vehicle.id &&
                  ActivityStatus.liveStates.contains(activity.status),
            )
            .toList();

        if (cachedLive.isNotEmpty) {
          activityId = cachedLive.first.id;
        }
      }
    }

    if (activityId == null || activityId.isEmpty) {
      showMessage(
        'Error',
        'No active activity to save. Please start again.',
      );
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

    // Capture memory snapshot for background save task
    final targetActivityId = activityId;
    _finalizingActivityIds.add(targetActivityId);

    final finalDriverId = selectedDriver.value?.id;
    final finalDuration = timerController.durationSeconds;
    final finalRate = _rate;
    final finalAmount = timerController.amount.value.toInt();
    final finalDescription =
        description.text.trim().isEmpty ? null : description.text.trim();
    final preCapturedStopLoc = _capturedStopLocation;

    // Clean form and reset local timer IMMEDIATELY so new activity can start right away
    _isFinalizingActivity = true;
    currentActivityId = null;
    _capturedStopLocation = null;
    timerController.reset();
    resetForm();
    _isFinalizingActivity = false;

    for (final timer in _syncTimers.values) {
      timer.cancel();
    }
    _syncTimers.clear();

    showMessage(
      'Success',
      'Activity is saving in background. Ready for new activity.',
    );

    // Execute background save task asynchronously
    _saveActivityInBackground(
      activityId: targetActivityId,
      customer: customer,
      customerIdsBeforeSave: customerIdsBeforeSave,
      driverId: finalDriverId,
      duration: finalDuration,
      rate: finalRate,
      amount: finalAmount,
      description: finalDescription,
      preCapturedStopLoc: preCapturedStopLoc,
    );
  }

  void _saveActivityInBackground({
    required String activityId,
    CustomerModel? customer,
    required Set<String> customerIdsBeforeSave,
    String? driverId,
    required int duration,
    required int rate,
    required int amount,
    String? description,
    ActivityLocationModel? preCapturedStopLoc,
  }) async {
    try {
      final latest = await firebaseService.getRecordById(
        'activities',
        activityId,
      );

      final latestStatus = latest?['status']?.toString();

      customer ??= await saveCustomer();

      // Ensure stop location is available
      ActivityLocationModel? stopLoc = preCapturedStopLoc;
      if (stopLoc == null) {
        try {
          stopLoc = await LocationService.instance.captureCurrentLocation();
        } catch (_) {}
      }

      final now = DateTime.now();

      final updatedData = {
        'customerId': customer.id,
        'driverId': driverId,
        'endTime': now.toUtc().toIso8601String(),
        'duration': duration,
        'rate': rate,
        'amount': amount,
        'paidAmount': 0,
        'dueAmount': amount,
        'description': description,
        'status': ActivityStatus.completed,
        'updatedAt': now.toUtc().toIso8601String(),
      };

      await firebaseService.updateRecord(
        'activities',
        activityId,
        updatedData,
      );

      if (stopLoc != null) {
        await LocationService.instance.saveStopLocation(activityId, stopLoc);
      }

      await AuditService.instance.log(
        action: 'activity_completed',
        performedBy: LoginController.loginUser.id,
        targetRecordId: activityId,
        oldValue: {'status': latestStatus},
        newValue: {'status': ActivityStatus.completed},
      );

      await _clearVehicleActive();
      debugPrint('MonitorController background save completed: $activityId');
    } catch (error) {
      debugPrint('MonitorController _saveActivityInBackground error: $error');
    } finally {
      _finalizingActivityIds.remove(activityId);
    }
  }

  Future<CustomerModel> saveCustomer() async {
    final selected = selectedCustomer.value;
    if (selected != null) return selected;

    final customerPhone = phone.text.trim();

    // Only dedupe by phone when one was actually provided. Phone number is
    // NOT enforced by the UI (no Form/validate() gates this screen), so
    // several customers can genuinely have a blank phone - matching on ''
    // would silently merge every new no-phone customer into whichever
    // blank-phone customer happens to exist first in the cache.
    final existing = customerPhone.isEmpty
        ? null
        : cache.getRecordByValue<CustomerModel>(
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

    await firebaseService.saveRecord('customers',customer.id,customer.toMap(),);

    selectedCustomer.value = customer;
    return customer;
  }

  Future<void> _rollbackNewCustomer(CustomerModel customer) async {
    try {
      await firebaseService.deleteRecord('customers', customer.id);
    } catch (error) {
      debugPrint(
        'MonitorController._rollbackNewCustomer(${customer.id}): $error',
      );
    }

    if (selectedCustomer.value?.id == customer.id) {
      selectedCustomer.value = null;
    }
  }

  int get _rate => int.tryParse(rate.text.trim()) ?? 0;

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
