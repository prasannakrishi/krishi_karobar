import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';

import '../models/user_model.dart';
import '../features/authentication/screens/login/login_screen.dart';

class UserProfileIcon extends StatefulWidget {
  final MonitorController activityController;
  const UserProfileIcon({super.key, required this.activityController});

  @override
  _UserProfileIconState createState() => _UserProfileIconState();
}

class _UserProfileIconState extends State<UserProfileIcon> {
  UserModel? _userModel;


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = _userModel?.fullname ?? user?.displayName ?? 'Anonymous';
    final userId = _userModel?.uId;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.person),
      onSelected: (value) async {
        if (value == 'logout') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'username',
          enabled: false,
          child: Text('Signed in as: $userName'),
        ),
        PopupMenuItem<String>(
          value: 'userid',
          enabled: false,
          child: Text('User ID: $userId'),
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
