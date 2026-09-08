import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';

class UserProfileIcon extends StatelessWidget {
  final MonitorController activityController;

  const UserProfileIcon({
    super.key,
    required this.activityController,
  });

  @override
  Widget build(BuildContext context) {
    final user = LoginController.loginUser;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.person),
      onSelected: (value) async {
        if (value == 'logout') {
          await Get.find<LoginController>().logout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          value: 'username',
          child: Text('Signed in as: ${user.fullname}'),
        ),
        PopupMenuItem<String>(
          enabled: false,
          value: 'userid',
          child: Text('User ID: ${user.uId}'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
          ),
        ),
      ],
    );
  }
}