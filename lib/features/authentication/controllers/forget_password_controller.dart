



import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../utils/helper/helper_widgets.dart';
import '../../../utils/helper/network_manager.dart';
import '../../../utils/popups/full_screen_loader.dart';

class ForgetPasswordController extends GetxController{
  static ForgetPasswordController get instance => Get.find();

  /// Variables
  final email = TextEditingController();
  GlobalKey<FormState> forgetPasswordFormKey = GlobalKey<FormState>();

  /// Send Reset Password Email
  Future<void> sendPasswordResetOTP() async{
    try{


      // Check Internet Connection
      final isConnected = await NetworkManager.instance.isConnected();
      if(!isConnected){
        return ;
      }

      // FormValidation
      if(!forgetPasswordFormKey.currentState!.validate()){
        UFullScreenLoader.stopLoading();
        return ;
      }

      // Remove Loader
      UFullScreenLoader.stopLoading();

    }catch(e){
      // Remove Loader
      UFullScreenLoader.stopLoading();
      errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }

  Future<void> resendPasswordResetOTP(String email) async{
    try{


      // Check Internet Connection
      final isConnected = await NetworkManager.instance.isConnected();
      if(!isConnected){
        UFullScreenLoader.stopLoading();
        return ;
      }

      // Remove Loader
      UFullScreenLoader.stopLoading();

      // Show Success Message
      successSnackBar(title: 'Email Sent',message: 'Email Link Sent to Reset your Password'.tr);

    }catch(e){
      // Remove Loader
      UFullScreenLoader.stopLoading();
      errorSnackBar(title: 'Oh Snap!', message: e.toString());
    }
  }
}