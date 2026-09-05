import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

    if (result.contains(ConnectivityResult.wifi) || result.contains(ConnectivityResult.mobile)) {
      _connectionStatus.value = result.firstWhere((status) => status != ConnectivityResult.none, orElse: () => ConnectivityResult.none);
    } else{
      _connectionStatus.value = ConnectivityResult.none;
      warningSnackBar(title: 'No Internet Connection');
    }
  }

  Future<bool> isConnected() async {
    try {
      final result = await _connectivity.checkConnectivity();

      if (!result.contains(ConnectivityResult.wifi) && !result.contains(ConnectivityResult.mobile)) return false;
      return await hasInternetAccess();
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  @override
  void onClose() {
    _connectivitySubscription.cancel();
    super.onClose();
  }
}