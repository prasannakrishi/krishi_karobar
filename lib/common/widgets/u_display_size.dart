import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/local_storage/storage_utility.dart';

enum UDisplaySize {
  compact,
  small, // Default
  medium,
  large;

  static UDisplaySize fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'compact':
        return UDisplaySize.compact;
      case 'medium':
        return UDisplaySize.medium;
      case 'large':
        return UDisplaySize.large;
      case 'small':
      default:
        return UDisplaySize.small;
    }
  }

  String get label {
    switch (this) {
      case UDisplaySize.compact:
        return 'Compact';
      case UDisplaySize.small:
        return 'Small (Default)';
      case UDisplaySize.medium:
        return 'Medium';
      case UDisplaySize.large:
        return 'Large';
    }
  }

  double get fieldHeight {
    switch (this) {
      case UDisplaySize.compact:
        return 38.0;
      case UDisplaySize.small:
        return 44.0;
      case UDisplaySize.medium:
        return 50.0;
      case UDisplaySize.large:
        return 56.0;
    }
  }

  EdgeInsets get fieldPadding {
    switch (this) {
      case UDisplaySize.compact:
        return const EdgeInsets.symmetric(horizontal: 10, vertical: 6);
      case UDisplaySize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case UDisplaySize.medium:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      case UDisplaySize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  double get fontSize {
    switch (this) {
      case UDisplaySize.compact:
        return 12.0;
      case UDisplaySize.small:
        return 13.5;
      case UDisplaySize.medium:
        return 15.0;
      case UDisplaySize.large:
        return 17.0;
    }
  }

  double get labelSize {
    switch (this) {
      case UDisplaySize.compact:
        return 11.0;
      case UDisplaySize.small:
        return 12.0;
      case UDisplaySize.medium:
        return 13.5;
      case UDisplaySize.large:
        return 15.0;
    }
  }

  double get iconSize {
    switch (this) {
      case UDisplaySize.compact:
        return 16.0;
      case UDisplaySize.small:
        return 18.0;
      case UDisplaySize.medium:
        return 21.0;
      case UDisplaySize.large:
        return 24.0;
    }
  }

  double get buttonHeight {
    switch (this) {
      case UDisplaySize.compact:
        return 36.0;
      case UDisplaySize.small:
        return 42.0;
      case UDisplaySize.medium:
        return 48.0;
      case UDisplaySize.large:
        return 54.0;
    }
  }

  EdgeInsets get buttonPadding {
    switch (this) {
      case UDisplaySize.compact:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
      case UDisplaySize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case UDisplaySize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 10);
      case UDisplaySize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    }
  }

  double get borderRadius {
    switch (this) {
      case UDisplaySize.compact:
        return 6.0;
      case UDisplaySize.small:
        return 8.0;
      case UDisplaySize.medium:
        return 10.0;
      case UDisplaySize.large:
        return 12.0;
    }
  }

  double get spacing {
    switch (this) {
      case UDisplaySize.compact:
        return 8.0;
      case UDisplaySize.small:
        return 12.0;
      case UDisplaySize.medium:
        return 16.0;
      case UDisplaySize.large:
        return 20.0;
    }
  }
}

class UDisplaySizeController extends GetxController {
  static UDisplaySizeController get instance {
    if (Get.isRegistered<UDisplaySizeController>()) {
      return Get.find<UDisplaySizeController>();
    }
    return Get.put(UDisplaySizeController(), permanent: true);
  }

  static const String _storageKey = 'u_display_size';

  final Rx<UDisplaySize> displaySize = UDisplaySize.small.obs;

  @override
  void onInit() {
    super.onInit();
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final saved = ULocalStorage.instance().readData<String>(_storageKey);
      if (saved != null && saved.isNotEmpty) {
        displaySize.value = UDisplaySize.fromString(saved);
      }
    } catch (_) {}
  }

  void setDisplaySize(UDisplaySize size) {
    displaySize.value = size;
    try {
      ULocalStorage.instance().saveData(_storageKey, size.name);
    } catch (_) {}
  }
}
