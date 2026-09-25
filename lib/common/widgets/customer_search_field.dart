import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/theme/widget_themes/custom_decoration.dart';

class CustomerSearchField extends StatefulWidget {
  const CustomerSearchField({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    this.onCustomerSelected,
    this.isCustomDecoration = true,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final void Function(CustomerModel customer)? onCustomerSelected;
  final bool isCustomDecoration;

  @override
  State<CustomerSearchField> createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  final filteredCustomers = <CustomerModel>[].obs;
  final showCustomerSuggestions = false.obs;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onCustomerNameChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onCustomerNameChanged);
    super.dispose();
  }

  void _onCustomerNameChanged() {
    final query = widget.nameController.text.trim().toLowerCase();
    if (query.length < 2) {
      filteredCustomers.clear();
      showCustomerSuggestions.value = false;
      return;
    }

    final cache = DataCacheService.instance;
    final matches = cache.customers.values.where((c) =>
        c.name.toLowerCase().contains(query) || c.phone.contains(query)).toList();

    filteredCustomers.assignAll(matches);
    showCustomerSuggestions.value = true;
  }

  void _selectCustomer(CustomerModel customer) {
    widget.nameController.text = customer.name;
    widget.phoneController.text = customer.phone;
    widget.addressController.text = customer.address;
    showCustomerSuggestions.value = false;
    filteredCustomers.clear();
    if (widget.onCustomerSelected != null) {
      widget.onCustomerSelected!(customer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.isCustomDecoration
        ? CustomDecoration.uInputDecoration(
            labelText: 'Customer Name',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, size: 20),
              onPressed: () {},
            ),
          )
        : const InputDecoration(
            labelText: 'Customer Name',
            suffixIcon: Icon(Icons.search),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.nameController,
          textCapitalization: TextCapitalization.words,
          decoration: decoration,
          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
        ),
        Obx(() {
          if (!showCustomerSuggestions.value || filteredCustomers.isEmpty) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.only(top: 2, bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCustomers.length,
                itemBuilder: (_, index) {
                  final customer = filteredCustomers[index];

                  return InkWell(
                    onTap: () => _selectCustomer(customer),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_outline, size: 18, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  customer.phone,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (customer.address.isNotEmpty)
                            Text(
                              customer.address,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.right,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
