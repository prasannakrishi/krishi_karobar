import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishi_karobar/common/widgets/appbar.dart';
import 'package:krishi_karobar/features/activity_monitor/controllers/monitor_controller.dart';
import 'package:krishi_karobar/models/customer_model.dart';
import 'package:krishi_karobar/features/activity_monitor/screen/monitor/widget/activity_details.dart';
import 'package:krishi_karobar/features/activity_monitor/screen/monitor/widget/customer_info.dart';
import 'package:krishi_karobar/features/activity_monitor/screen/monitor/widget/vehicle_info.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/utils/constants/sizes.dart';
import 'package:krishi_karobar/utils/helper/helper_widgets.dart';
import '../../../../utils/theme/widget_themes/custom_decoration.dart';
import '../../../../models/service_model.dart';
import '../../../../models/vehicle_model.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MonitorController>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: UAppBar(title: 'Activity Monitor'),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Vehicle Info Section ---
                  Obx(() {
                    final isCollapsed = controller.vehicleCollapsed.value;
                    final isEmpty = controller.isVehicleEmpty.value;
                    
                    return CustomDecoration.buildCollapsibleCard(
                      title: "VEHICLE INFO",
                      isCollapsed: isCollapsed,
                      onTap: () => controller.vehicleCollapsed.toggle(),
                      collapsedChild: Text(
                        isEmpty ? '—' : controller.vehicleNumber.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      child: VehicleInfo(controller: controller),
                    );
                  }),
                  
                  const SizedBox(height: USizes.spaceBtwItems),
                  
                  // --- Customer Info Section ---
                  Obx(() {
                    final isCollapsed = controller.customerCollapsed.value;
                    final isEmpty = controller.isCustomerEmpty.value;

                    return CustomDecoration.buildCollapsibleCard(
                      title: "CUSTOMER INFO",
                      isCollapsed: isCollapsed,
                      onTap: () => controller.customerCollapsed.toggle(),
                      collapsedChild: Text(
                        isEmpty ? '—' : controller.customerName.text,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      child: CustomerForm(controller: controller),
                    );
                  }),
                  
                  const SizedBox(height: USizes.spaceBtwItems),
                  
                  // --- Activity Details Section ---
                  ActivityForm(controller: controller),
                  
                  const SizedBox(height: 100),
                ],
              ),
              // Services Dropdown
              Obx(() {
                if (controller.filteredService.isEmpty) return const SizedBox.shrink();
                
                double topPos = 330;
                if (controller.vehicleCollapsed.value && controller.customerCollapsed.value) {
                  topPos = 120;
                } else if (controller.vehicleCollapsed.value) {
                  topPos = 230;
                }
                
                return floatingDropdown<ServiceModel>(
                  top: topPos,
                  items: controller.filteredService,
                  onClose: () => controller.filteredService.clear(),
                  titleBuilder: (s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(s.name), Text('रु ${s.rate}')],
                    ),
                  ),
                  onTap: (s) => controller.selectService(s),
                );
              }),

              // Vehicle Dropdown
              Obx(() {
                if (controller.filteredVehicle.isEmpty) return const SizedBox.shrink();
                return floatingDropdown<VehicleModel>(
                  top: 80,
                  items: controller.filteredVehicle,
                  onClose: () => controller.filteredVehicle.clear(),
                  titleBuilder: (v) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(v.number), Text(v.name)],
                    ),
                  ),
                  subtitleBuilder: (v) => Text(DataCacheService.instance.getUserName(v.ownerId)),
                  onTap: (v) => controller.selectVehicle(v),
                );
              }),

              // Customer Dropdown
              Obx(() {
                if (controller.filteredCustomers.isEmpty) return const SizedBox.shrink();
                return floatingDropdown<CustomerModel>(
                  top: 150,
                  items: controller.filteredCustomers,
                  onClose: () => controller.filteredCustomers.clear(),
                  titleBuilder: (c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(c.name), Text(c.address)],
                    ),
                  ),
                  subtitleBuilder: (c) => Text(c.phone),
                  onTap: (c) => controller.selectCustomer(c),
                );
              }),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomControlBar(controller),
    );
  }

  Widget _buildBottomControlBar(MonitorController controller) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
        child: Obx(() {
          final state = controller.timeController.state.value;
          final List<Widget> buttons = controller.buildControlButtons(state);

          return Row(
            children: buttons.map((button) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: button,
              ),
            )).toList(),
          );
        }),
      ),
    );
  }
}
