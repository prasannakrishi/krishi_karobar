import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:krishi_karobar/features/authentication/controllers/login_controllers.dart';
import '../../utils/constants/colors.dart';
import '../../utils/constants/sizes.dart';
import '../../utils/helper/helper_functions.dart';

class UAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showBackArrow;
  final bool showUserName;
  final IconData? leadingIcon;
  final List<Widget>? actions;
  final VoidCallback? leadingOnPressed;

  UAppBar(
      {super.key,
        this.title,
        this.titleWidget,
        this.showBackArrow = false,
        this.showUserName = true,
        this.leadingIcon,
        this.actions,
        this.leadingOnPressed});

  @override
  Widget build(BuildContext context) {
    final dark = UHelperFunctions.isDarkMode(context);
    return Padding(padding: const EdgeInsets.symmetric(),
      child: AppBar(
        toolbarHeight: USizes.appBarHeight,
        automaticallyImplyLeading: false,
        leading: showBackArrow ? IconButton(
          onPressed: () => Get.back(), icon:
          const Icon(Iconsax.arrow_left),color: dark ? UColors.white : UColors.dark ,) :
          leadingIcon != null ?
          IconButton(onPressed: leadingOnPressed, icon: Icon(leadingIcon)) : null,
        title:Row(
          children: [
            titleWidget ?? Text(title ?? '',
              style: TextStyle(color: dark ? UColors.white : UColors.dark,),
            ),
            if (showUserName) ...[
              const Spacer(),
              Text(LoginController.loginUser?.name ?? '',
                style: TextStyle(color: dark ? UColors.white : UColors.dark)
              ),
            ],
          ],
        ) ,
        actions: actions,
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(USizes.appBarHeight);
}
