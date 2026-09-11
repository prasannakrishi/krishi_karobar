import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'helper_widgets.dart';

class NetworkManager extends GetxController {
  static NetworkManager get instance => Get.find();

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final Rx<ConnectivityResult> _connectionStatus = ConnectivityResult.none.obs;

  Rx<ConnectivityResult> get connectionStatus => _connectionStatus;

  @override
  void onInit() {
    super.onInit();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _updateConnectionStatus(List<ConnectivityResult> result) async {
    final connected = result.any((status) =>
    status == ConnectivityResult.wifi ||
        status == ConnectivityResult.mobile ||
        status == ConnectivityResult.ethernet ||
        status == ConnectivityResult.vpn);

    if (connected) {
      _connectionStatus.value =
          result.firstWhere((status) => status != ConnectivityResult.none);
    } else {
      _connectionStatus.value = ConnectivityResult.none;
      warningSnackBar(title: 'No Internet Connection');
    }
  }

  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();

      return result.any((status) =>
      status == ConnectivityResult.wifi ||
          status == ConnectivityResult.mobile ||
          status == ConnectivityResult.ethernet ||
          status == ConnectivityResult.vpn);
    } on PlatformException {
      return false;
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}