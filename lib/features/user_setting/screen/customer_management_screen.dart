import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/app_scaffold.dart';
import '../../../common/widgets/access_denied_screen.dart';
import '../../../services/services.dart';
import '../../../utils/helper/helper_widgets.dart';
import '../controller/customer_controller.dart';
import 'widgets/customer_form.dart';

class CustomerManagementScreen extends StatelessWidget {
  CustomerManagementScreen({super.key});

  final controller = Get.isRegistered<CustomerController>()
      ? Get.find<CustomerController>()
      : Get.put(CustomerController(), permanent: true);

  @override
  Widget build(BuildContext context) {
    if (!Authz.can(Permissions.customerView) &&
        !Authz.can(Permissions.activityView)) {
      return const AccessDeniedScreen(title: 'Customers');
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
                      onChanged: controller.customersList.isEmpty
                          ? null
                          : (_) => controller.toggleSelectAll(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Center(
                  child: Text(
                    'Customers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (!multi &&
                    selected &&
                    (Authz.can(Permissions.customerEdit) ||
                        Authz.can(Permissions.activityView)))
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      final customer = controller.selectedListCustomer;
                      if (customer == null) return;

                      controller.startEdit(customer);
                      Get.to(() => CustomerForm());
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (selected &&
                    (Authz.can(Permissions.customerDelete) ||
                        Authz.can(Permissions.userDelete)))
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: controller.deleteSelectedCustomers,
                    icon: const Icon(Icons.delete_outline),
                  ),
                if (Authz.can(Permissions.customerCreate) ||
                    Authz.can(Permissions.activityView))
                  IconButton(
                    tooltip: 'Add Customer',
                    onPressed: () {
                      controller.startAdd();
                      Get.to(() => CustomerForm());
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
        final customers = controller.customersList;

        if (controller.isLoading.value && customers.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (customers.isEmpty) {
          return const Center(child: Text('No customers found'));
        }

        return uDataTable(
          columns: const [
            SizedBox(width: 42, child: Text('')),
            Text('ID'),
            Text('Name'),
            Text('Phone'),
            Text('Address'),
          ],
          rowValues: List.generate(customers.length, (index) {
            final customer = customers[index];
            final selected = controller.isRowSelected(customer.id);

            void onTap() {
              if (controller.selectionMode.value) {
                controller.toggleSelection(customer.id);
              } else {
                controller.selectRow(customer.id);
              }
            }

            void onLongPress() => controller.startMultiSelect(customer.id);

            return [
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: Checkbox(
                      value: selected,
                      onChanged: controller.selectionMode.value
                          ? (_) => controller.toggleSelection(customer.id)
                          : null,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    customer.uId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text((customer.phone != null && customer.phone!.isNotEmpty)? customer.phone!: "-",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Text(
                  customer.address.isEmpty ? '—' : customer.address,
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
