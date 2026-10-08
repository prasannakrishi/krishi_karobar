import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../models/models.dart';
import '../../controllers/activity_controller.dart';

class EditActivityDialog extends StatefulWidget {
  const EditActivityDialog({
    super.key,
    required this.activity,
    required this.controller,
  });

  final ActivityModel activity;
  final ActivityController controller;

  @override
  State<EditActivityDialog> createState() => _EditActivityDialogState();
}

class _EditActivityDialogState extends State<EditActivityDialog> {
  final _formKey = GlobalKey<FormState>();

  late String selectedCustomerId;
  late String selectedVehicleId;
  late String selectedServiceId;

  late TextEditingController durationMinutesController;
  late TextEditingController rateController;
  late TextEditingController amountController;
  late TextEditingController paidAmountController;
  late TextEditingController descriptionController;

  @override
  void initState() {
    super.initState();

    selectedCustomerId = widget.activity.customerId;
    selectedVehicleId = widget.activity.vehicleId;
    selectedServiceId = widget.activity.serviceId;

    // Convert seconds to minutes for user editing convenience
    final minutes = (widget.activity.duration / 60).round();
    durationMinutesController = TextEditingController(text: minutes.toString());
    rateController = TextEditingController(
      text: widget.activity.rate.toString(),
    );
    amountController = TextEditingController(
      text: widget.activity.amount.toString(),
    );
    paidAmountController = TextEditingController(
      text: widget.activity.paidAmount.toString(),
    );
    descriptionController = TextEditingController(
      text: widget.activity.description ?? '',
    );
  }

  @override
  void dispose() {
    durationMinutesController.dispose();
    rateController.dispose();
    amountController.dispose();
    paidAmountController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _recalculateAmount() {
    final minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;
    final rate = int.tryParse(rateController.text.trim()) ?? 0;
    final calculated = ((minutes / 60.0) * rate).round();
    amountController.text = calculated.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final minutes = int.tryParse(durationMinutesController.text.trim()) ?? 0;
    final durationSeconds = minutes * 60;
    final rate = int.tryParse(rateController.text.trim()) ?? 0;
    final amount = int.tryParse(amountController.text.trim()) ?? 0;
    final paidAmount = int.tryParse(paidAmountController.text.trim()) ?? 0;
    final description = descriptionController.text.trim();

    Get.back();

    await widget.controller.updateActivity(
      activity: widget.activity,
      customerId: selectedCustomerId,
      vehicleId: selectedVehicleId,
      serviceId: selectedServiceId,
      duration: durationSeconds,
      rate: rate,
      amount: amount,
      paidAmount: paidAmount,
      description: description,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = widget.controller.customers;
    final vehicles = widget.controller.vehicles;
    final services = widget.controller.services;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Edit Activity (${widget.activity.uId})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer Selection
                _EditCustomerAutocomplete(
                  selectedCustomerId: selectedCustomerId,
                  customers: customers,
                  onSelected: (customer) {
                    setState(() {
                      selectedCustomerId = customer.id;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Vehicle Selection
                DropdownButtonFormField<String>(
                  initialValue: vehicles.any((v) => v.id == selectedVehicleId)
                      ? selectedVehicleId
                      : (vehicles.isNotEmpty ? vehicles.first.id : null),
                  decoration: const InputDecoration(
                    labelText: 'Vehicle',
                    border: OutlineInputBorder(),
                  ),
                  items: vehicles.map((vehicle) {
                    return DropdownMenuItem<String>(
                      value: vehicle.id,
                      child: Text(vehicle.number),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedVehicleId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Service Selection
                DropdownButtonFormField<String>(
                  initialValue: services.any((s) => s.id == selectedServiceId)
                      ? selectedServiceId
                      : (services.isNotEmpty ? services.first.id : null),
                  decoration: const InputDecoration(
                    labelText: 'Service',
                    border: OutlineInputBorder(),
                  ),
                  items: services.map((service) {
                    return DropdownMenuItem<String>(
                      value: service.id,
                      child: Text(service.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => selectedServiceId = val);
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Duration (Minutes) & Rate / Hour
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: durationMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Duration (Min)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _recalculateAmount(),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (int.tryParse(val.trim()) == null)
                            return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: rateController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Rate (रु/Hr)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _recalculateAmount(),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (int.tryParse(val.trim()) == null)
                            return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Amount & Paid Amount
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Amount (रु)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (int.tryParse(val.trim()) == null)
                            return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Paid (रु)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Required';
                          if (int.tryParse(val.trim()) == null)
                            return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description with Autocomplete suggestions
                _EditDescriptionAutocomplete(
                  controller: descriptionController,
                  activityController: widget.controller,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save Changes')),
      ],
    );
  }
}

class _EditCustomerAutocomplete extends StatefulWidget {
  const _EditCustomerAutocomplete({
    required this.selectedCustomerId,
    required this.customers,
    required this.onSelected,
  });

  final String selectedCustomerId;
  final List<CustomerModel> customers;
  final ValueChanged<CustomerModel> onSelected;

  @override
  State<_EditCustomerAutocomplete> createState() =>
      _EditCustomerAutocompleteState();
}

class _EditCustomerAutocompleteState extends State<_EditCustomerAutocomplete> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  CustomerModel? get selectedCustomer {
    try {
      return widget.customers.firstWhere(
        (customer) => customer.id == widget.selectedCustomerId,
      );
    } catch (_) {
      return null;
    }
  }

  String _customerDisplayName(CustomerModel customer) {
    return '${customer.name}  ${customer.address}\n${customer.phone}';
  }

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: selectedCustomer != null
          ? _customerDisplayName(selectedCustomer!)
          : '',
    );

    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _EditCustomerAutocomplete oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedCustomerId != widget.selectedCustomerId) {
      final customer = selectedCustomer;

      if (customer != null) {
        _controller.text = _customerDisplayName(customer);
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<CustomerModel>(
      textEditingController: _controller,
      focusNode: _focusNode,

      // Tap/focus गर्दा सबै customer देखाउने
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return widget.customers;
        }

        return widget.customers.where((customer) {
          final name = customer.name.toLowerCase();
          final address = customer.address.toLowerCase();
          final phone = customer.phone!.toLowerCase();

          return name.contains(query) ||
              address.contains(query) ||
              phone.contains(query);
        });
      },

      onSelected: (CustomerModel customer) {
        widget.onSelected(customer);

        final displayText = _customerDisplayName(customer);

        _controller.text = displayText;
        _controller.selection = TextSelection.collapsed(
          offset: displayText.length,
        );
      },

      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,

              decoration: const InputDecoration(
                labelText: 'Customer',
                hintText: 'Type customer name / phone / address',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),

              // Field editable हुनेछ
              onChanged: (_) {
                // Typing गर्दा RawAutocomplete आफैं filter गर्छ
              },

              onFieldSubmitted: (_) {
                onFieldSubmitted();
              },

              validator: (value) {
                if (widget.selectedCustomerId.isEmpty) {
                  return 'Please select customer';
                }

                return null;
              },
            );
          },

      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.toList();

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 240, // लगभग 4 rows
                maxWidth: 400,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionList.length,
                itemBuilder: (context, index) {
                  final customer = optionList[index];

                  return InkWell(
                    onTap: () {
                      onSelected(customer);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_outline, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${customer.address} • ${customer.phone}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditDescriptionAutocomplete extends StatefulWidget {
  const _EditDescriptionAutocomplete({
    required this.controller,
    required this.activityController,
  });

  final TextEditingController controller;
  final ActivityController activityController;

  @override
  State<_EditDescriptionAutocomplete> createState() =>
      _EditDescriptionAutocompleteState();
}

class _EditDescriptionAutocompleteState
    extends State<_EditDescriptionAutocomplete> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      focusNode: _focusNode,
      textEditingController: widget.controller,
      optionsBuilder: (TextEditingValue textEditingValue) {
        final suggestions = widget.activityController.recentDescriptions;
        final query = textEditingValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return suggestions;
        }

        return suggestions.where((desc) => desc.toLowerCase().contains(query));
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.collapsed(
          offset: selection.length,
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Type or select previous description',
                border: const OutlineInputBorder(),
                suffixIcon: PopupMenuButton<String>(
                  icon: const Icon(Icons.arrow_drop_down),
                  tooltip: 'Previous Descriptions',
                  onSelected: (String value) {
                    widget.controller.text = value;
                    widget.controller.selection = TextSelection.collapsed(
                      offset: value.length,
                    );
                  },
                  itemBuilder: (BuildContext context) {
                    final suggestions =
                        widget.activityController.recentDescriptions;
                    if (suggestions.isEmpty) {
                      return const [
                        PopupMenuItem<String>(
                          enabled: false,
                          child: Text('No previous descriptions found'),
                        ),
                      ];
                    }
                    return suggestions.map((desc) {
                      return PopupMenuItem<String>(
                        value: desc,
                        child: Text(desc),
                      );
                    }).toList();
                  },
                ),
              ),
              onFieldSubmitted: (_) => onFieldSubmitted(),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 350),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
