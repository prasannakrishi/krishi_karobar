import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';
import '../../../services/services.dart';
import '../../../utils/exceptions/app_exceptions.dart';
import 'package:krishi_karobar/features/controllers.dart';

class ServiceController extends GetxController {
  static ServiceController get instance => Get.find<ServiceController>();

  final FirebaseService firebaseService = FirebaseService();
  final SequenceService sequenceService = SequenceService.instance;
  final DataCacheService cache = DataCacheService.instance;
  final Uuid uuid = const Uuid();

  // Common unit presets shown in the service form's Unit dropdown.
  static const List<String> units = [
    'hour',
    'day',
    'trip',
    'bigha',
    'kattha',
    'acre',
  ];

  final services = <ServiceModel>[].obs;
  final selectedServiceIds = <String>{}.obs;
  final selectionMode = false.obs;
  final isLoading = false.obs;

  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final rateController = TextEditingController();

  final selectedUnit = 'hour'.obs;
  final selectedStatus = 'active'.obs;

  final isEditMode = false.obs;
  ServiceModel? editingService;

  @override
  void onInit() {
    super.onInit();
    loadServices();
  }

  void loadServices() {
    services.assignAll(
      cache.getCachedRecords<ServiceModel>('services'),
    );
  }

  bool isSelected(String id) => selectedServiceIds.contains(id);

  bool get hasSelection => selectedServiceIds.isNotEmpty;
  bool get hasSingleSelection => selectedServiceIds.length == 1;
  bool get hasMultipleSelection => selectedServiceIds.length > 1;

  bool get isAllSelected =>
      services.isNotEmpty && selectedServiceIds.length == services.length;

  bool get isPartiallySelected =>
      selectedServiceIds.isNotEmpty && !isAllSelected;

  ServiceModel? get selectedService {
    if (!hasSingleSelection) return null;
    return services.firstWhereOrNull(
      (service) => service.id == selectedServiceIds.first,
    );
  }

  void selectService(String id) {
    if (selectionMode.value) {
      toggleSelection(id);
      return;
    }

    selectedServiceIds
      ..clear()
      ..add(id);
    selectedServiceIds.refresh();
  }

  void startMultiSelect(String id) {
    selectionMode.value = true;
    selectedServiceIds
      ..clear()
      ..add(id);
    selectedServiceIds.refresh();
  }

  void toggleSelection(String id) {
    if (!selectionMode.value) return;

    if (selectedServiceIds.contains(id)) {
      selectedServiceIds.remove(id);
    } else {
      selectedServiceIds.add(id);
    }

    selectedServiceIds.refresh();

    if (selectedServiceIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void toggleSelectAll() {
    if (!selectionMode.value) {
      selectionMode.value = true;
    }

    if (isAllSelected) {
      selectedServiceIds.clear();
    } else {
      selectedServiceIds
        ..clear()
        ..addAll(services.map((service) => service.id));
    }

    selectedServiceIds.refresh();

    if (selectedServiceIds.isEmpty) {
      selectionMode.value = false;
    }
  }

  void clearSelection() {
    selectedServiceIds.clear();
    selectionMode.value = false;
    selectedServiceIds.refresh();
  }

  void startAdd() {
    clearForm();
    isEditMode.value = false;
    editingService = null;
  }

  void startEdit(ServiceModel service) {
    editingService = service;
    isEditMode.value = true;

    nameController.text = service.name;
    descriptionController.text = service.description;
    rateController.text = _formatRate(service.rate);

    selectedUnit.value =
        units.contains(service.unit) ? service.unit : units.first;
    selectedStatus.value = service.isActive ? 'active' : 'inactive';
  }

  void clearForm() {
    nameController.clear();
    descriptionController.clear();
    rateController.clear();

    selectedUnit.value = units.first;
    selectedStatus.value = 'active';

    isEditMode.value = false;
    editingService = null;
  }

  String _formatRate(int rate) {
    return rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : rate.toString();
  }

  Future<bool> saveService() async {
    try {
      Authz.requirePermission(
        isEditMode.value ? Permissions.serviceEdit : Permissions.serviceCreate,
      );
    } on AppException catch (e) {
      _error(e.message);
      return false;
    }

    final name = nameController.text.trim();
    final description = descriptionController.text.trim();
    final rateText = rateController.text.trim();

    if (name.isEmpty) {
      _error('Name is required.');
      return false;
    }

    final rate = int.tryParse(rateText);
    if (rate == null || rate <= 0) {
      _error('Enter a valid rate.');
      return false;
    }

    return isEditMode.value
        ? _updateService(
            name: name,
            description: description,
            rate: rate,
          )
        : _createService(
            name: name,
            description: description,
            rate: rate,
          );
  }

  Future<bool> _createService({
    required String name,
    required String description,
    required int rate,
  }) async {
    isLoading.value = true;

    try {
      final id = uuid.v4();
      final uId = await sequenceService.generateSequence('S');
      final now = DateTime.now().toUtc();

      final service = ServiceModel(
        id: id,
        uId: uId,
        name: name,
        description: description,
        rate: rate,
        unit: selectedUnit.value,
        isActive: selectedStatus.value == 'active',
        createdAt: now,
        createdBy: LoginController.loginUser.id,
      );

      await firebaseService.saveRecord(
        'services',
        id,
        service.toMap(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadServices();
      clearSelection();
      return true;
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('ServiceController createService: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _updateService({
    required String name,
    required String description,
    required int rate,
  }) async {
    final service = editingService;
    if (service == null) return false;

    isLoading.value = true;

    try {
      final now = DateTime.now().toUtc();

      final updatedData = {
        'name': name,
        'description': description,
        'rate': rate,
        'unit': selectedUnit.value,
        'isActive': selectedStatus.value == 'active',
        'updatedAt': now.toIso8601String(),
        'updatedBy': LoginController.loginUser.id,
      };

      await firebaseService.updateRecord(
        'services',
        service.id,
        updatedData,
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadServices();
      clearSelection();
      return true;
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('ServiceController updateService: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// A service is "in use" if any vehicle supports it, or any activity
  /// (past or ongoing) was recorded against it. Such services are kept
  /// out of deletion to avoid breaking those references.
  bool _isServiceInUse(String serviceId) {
    final usedByVehicle = cache
        .getCachedRecords<VehicleModel>('vehicles')
        .any((vehicle) => vehicle.supportServiceIds.contains(serviceId));

    if (usedByVehicle) return true;

    return cache
        .getCachedRecords<ActivityModel>('activities')
        .any((activity) => activity.serviceId == serviceId);
  }

  Future<void> deleteSelectedServices() async {
    if (selectedServiceIds.isEmpty) return;

    try {
      Authz.requirePermission(Permissions.serviceDelete);
    } on AppException catch (e) {
      _error(e.message);
      return;
    }

    final ids = selectedServiceIds.toList();
    final blockedNames = <String>[];
    final deletableIds = <String>[];

    for (final id in ids) {
      if (_isServiceInUse(id)) {
        final service = services.firstWhereOrNull((s) => s.id == id);
        blockedNames.add(service?.name ?? id);
      } else {
        deletableIds.add(id);
      }
    }

    if (blockedNames.isNotEmpty) {
      _error(
        blockedNames.length == 1
            ? '"${blockedNames.first}" is already assigned to a vehicle or '
                'activity and cannot be deleted.'
            : 'These services are in use and cannot be deleted: '
                '${blockedNames.join(', ')}.',
      );
    }

    if (deletableIds.isEmpty) return;

    isLoading.value = true;

    try {
      for (final id in deletableIds) {
        await firebaseService.deleteRecord('services', id);
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));
      loadServices();
      clearSelection();
    } catch (e) {
      _error(AppException.messageOf(e));
      debugPrint('ServiceController deleteServices: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void _error(String message) {
    Get.snackbar(
      'Service',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    rateController.dispose();
    super.onClose();
  }
}
