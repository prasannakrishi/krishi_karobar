import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import '../../../common/widgets/access_denied_screen.dart';
import '../../../services/services.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../controller/user_controller.dart';
import 'widgets/user_form.dart';

class UserManagementScreen extends StatelessWidget {
  UserManagementScreen({super.key});

  final controller = Get.put(UserController());

  @override
  Widget build(BuildContext context) {
    if (!Authz.can(Permissions.userView)) {
      return const AccessDeniedScreen(title: 'Users');
    }

    return UAppScaffold(
      transparentBackground: false,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Obx(() {
          final selected = controller.hasSelection;
          final multi = controller.selectionMode.value;

          return SizedBox(
            height: kToolbarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: controller.clearSelection,
                  icon: const Icon(Icons.arrow_back),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 48,
                  child: Center(
                    child: Checkbox(
                      value: controller.isAllSelected
                          ? true
                          : controller.isPartiallySelected
                          ? null
                          : false,
                      tristate: true,
                      onChanged: controller.users.isEmpty
                          ? null
                          : (_) => controller.toggleSelectAll(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Center(
                  child: Text(
                    'Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                if (!multi && selected && Authz.can(Permissions.userEdit))
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      final user = controller.selectedUser;
                      if (user == null) return;

                      controller.startEdit(user);
                      Get.to(() => UserForm());
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (selected && Authz.can(Permissions.userDelete))
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: controller.deleteSelectedUsers,
                    icon: const Icon(Icons.delete_outline),
                  ),
                if (Authz.can(Permissions.userCreate))
                  IconButton(
                    tooltip: 'Add',
                    onPressed: () {
                      controller.startAdd();
                      Get.to(() => UserForm());
                    },
                    icon: const Icon(Icons.add),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          );
        }),
      ),
      body: Obx(() {
        if (controller.users.isEmpty) {
          return const Center(
            child: Text('No users found'),
          );
        }

        return uDataTable(
          columns: const [
            SizedBox(width: 42, child: Text('')),
            Text('Name'),
            Text('ID'),
            Text('Role'),
            Text('Status'),
          ],
          rowValues: List.generate(controller.users.length, (index) {
            final user = controller.users[index];
            final selected = controller.selectedUserIds.contains(user.id);

            final role = user.roles.isEmpty ? '—' : user.roles.join(', ');

            return [
              GestureDetector(
                onTap: () {
                  if (controller.selectionMode.value) {
                    controller.toggleSelection(user.id);
                  } else {
                    controller.selectUser(user.id);
                  }
                },
                onLongPress: () => controller.startMultiSelect(user.id),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Checkbox(
                      value: selected,
                      onChanged: controller.selectionMode.value
                          ? (_) => controller.toggleSelection(user.id)
                          : null,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.selectionMode.value) {
                    controller.toggleSelection(user.id);
                  } else {
                    controller.selectUser(user.id);
                  }
                },
                onLongPress: () => controller.startMultiSelect(user.id),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    user.fullname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.selectionMode.value) {
                    controller.toggleSelection(user.id);
                  } else {
                    controller.selectUser(user.id);
                  }
                },
                onLongPress: () => controller.startMultiSelect(user.id),
                child: Text(
                  user.uId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.selectionMode.value) {
                    controller.toggleSelection(user.id);
                  } else {
                    controller.selectUser(user.id);
                  }
                },
                onLongPress: () => controller.startMultiSelect(user.id),
                child: Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.selectionMode.value) {
                    controller.toggleSelection(user.id);
                  } else {
                    controller.selectUser(user.id);
                  }
                },
                onLongPress: () => controller.startMultiSelect(user.id),
                child: Text(
                  user.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ];
          }),
        );
      }),
    );
  }
}