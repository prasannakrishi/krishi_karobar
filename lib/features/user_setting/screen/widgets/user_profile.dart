import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../authentication/controllers/login_controllers.dart';
import '../profile_screen.dart';

class UserProfile extends StatelessWidget {
  const UserProfile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 1,
                    child: CircleAvatar(
                      radius: 30,
                      child: Icon(Iconsax.user, size: 30),
                    ),
                  ),
                  const SizedBox(width: 10,),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(LoginController.loginUser.uid),
                        const SizedBox(height: 5),
                        Text(
                          LoginController.loginUser.name,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),

                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Iconsax.edit),
                          onPressed: () => Get.to(() => const ProfileScreen()),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ]
          )
        ]
      )
    );
  }
}

