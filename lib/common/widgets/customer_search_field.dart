import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/models.dart';
import '../../services/services.dart';
import '../../utils/theme/widget_themes/custom_decoration.dart';
import '../../utils/validators/validation.dart';

class CustomerSearchField extends StatefulWidget {
  const CustomerSearchField({
    super.key,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    this.onCustomerSelected,
    this.isCustomDecoration = true,
    this.showExtraFields = true,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final void Function(CustomerModel customer)? onCustomerSelected;
  final bool isCustomDecoration;
  final bool showExtraFields;

  @override
  State<CustomerSearchField> createState() => _CustomerSearchFieldState();
}

class _CustomerSearchFieldState extends State<CustomerSearchField> {
  final filteredCustomers = <CustomerModel>[].obs;
  final filteredAddresses = <String>[].obs;
  final filteredPhones = <String>[].obs;

  OverlayEntry? _customerOverlayEntry;
  OverlayEntry? _addressOverlayEntry;
  OverlayEntry? _phoneOverlayEntry;

  final LayerLink _nameLayerLink = LayerLink();
  final LayerLink _addressLayerLink = LayerLink();
  final LayerLink _phoneLayerLink = LayerLink();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  double _nameWidth = 0.0;
  double _addressWidth = 0.0;
  double _phoneWidth = 0.0;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onCustomerNameChanged);
    widget.addressController.addListener(_onAddressChanged);
    widget.phoneController.addListener(_onPhoneChanged);

    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus) {
        _hideOverlay(_customerOverlayEntry, () => _customerOverlayEntry = null);
      }
    });
    _addressFocusNode.addListener(() {
      if (!_addressFocusNode.hasFocus) {
        _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
      }
    });
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus) {
        _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);
      }
    });
  }

  @override
  void dispose() {
    _hideOverlay(_customerOverlayEntry, () => _customerOverlayEntry = null);
    _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
    _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);

    _nameFocusNode.dispose();
    _addressFocusNode.dispose();
    _phoneFocusNode.dispose();

    widget.nameController.removeListener(_onCustomerNameChanged);
    widget.addressController.removeListener(_onAddressChanged);
    widget.phoneController.removeListener(_onPhoneChanged);
    super.dispose();
  }

  void _hideOverlay(OverlayEntry? entry, VoidCallback onCleared) {
    entry?.remove();
    onCleared();
  }

  void _onCustomerNameChanged() {
    if (!_nameFocusNode.hasFocus) return;

    final query = widget.nameController.text.trim().toLowerCase();
    if (query.length < 2) {
      filteredCustomers.clear();
      _hideOverlay(_customerOverlayEntry, () => _customerOverlayEntry = null);
      return;
    }

    final cache = DataCacheService.instance;
    final matches = cache.customers.values.where((c) =>
        c.name.toLowerCase().contains(query) || c.phone!.contains(query)).toList();

    filteredCustomers.assignAll(matches);
    if (matches.isNotEmpty && _nameFocusNode.hasFocus) {
      _showSuggestionOverlay(
        link: _nameLayerLink,
        width: _nameWidth > 0 ? _nameWidth : 250,
        itemCount: filteredCustomers.length,
        itemBuilder: (context, index) {
          final customer = filteredCustomers[index];
          return InkWell(
            onTap: () {
              widget.nameController.text = customer.name;
              widget.phoneController.text = customer.phone!;
              widget.addressController.text = customer.address;
              _hideOverlay(_customerOverlayEntry, () => _customerOverlayEntry = null);
              _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
              _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);
              if (widget.onCustomerSelected != null) {
                widget.onCustomerSelected!(customer);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.person_outline, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📞 ${customer.phone!.isEmpty ? 'No Phone' : customer.phone}  •  📍 ${customer.address.isEmpty ? 'No Address' : customer.address}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        activeEntry: _customerOverlayEntry,
        onEntryChanged: (e) => _customerOverlayEntry = e,
      );
    } else {
      _hideOverlay(_customerOverlayEntry, () => _customerOverlayEntry = null);
    }
  }

  void _onAddressChanged() {
    if (!_addressFocusNode.hasFocus) return;

    final query = widget.addressController.text.trim().toLowerCase();
    if (query.isEmpty) {
      filteredAddresses.clear();
      _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
      return;
    }

    final cache = DataCacheService.instance;
    final addresses = <String>{};
    for (final c in cache.customers.values) {
      if (c.address.isNotEmpty) addresses.add(c.address);
    }

    final matches = addresses
        .where((addr) => addr.toLowerCase().contains(query))
        .toList();

    filteredAddresses.assignAll(matches);
    if (matches.isNotEmpty && _addressFocusNode.hasFocus) {
      _showSuggestionOverlay(
        link: _addressLayerLink,
        width: _addressWidth > 0 ? _addressWidth : 150,
        itemCount: filteredAddresses.length,
        itemBuilder: (context, index) {
          final addr = filteredAddresses[index];
          return InkWell(
            onTap: () {
              widget.addressController.text = addr;
              _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      addr,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        activeEntry: _addressOverlayEntry,
        onEntryChanged: (e) => _addressOverlayEntry = e,
      );
    } else {
      _hideOverlay(_addressOverlayEntry, () => _addressOverlayEntry = null);
    }
  }

  void _onPhoneChanged() {
    if (!_phoneFocusNode.hasFocus) return;

    final query = widget.phoneController.text.trim();
    if (query.isEmpty) {
      filteredPhones.clear();
      _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);
      return;
    }

    final cache = DataCacheService.instance;
    final phones = <String>{};
    for (final c in cache.customers.values) {
      if (c.phone!.isNotEmpty) phones.add(c.phone!);
    }

    final matches = phones
        .where((ph) => ph.contains(query))
        .toList();

    filteredPhones.assignAll(matches);
    if (matches.isNotEmpty && _phoneFocusNode.hasFocus) {
      _showSuggestionOverlay(
        link: _phoneLayerLink,
        width: _phoneWidth > 0 ? _phoneWidth : 150,
        itemCount: filteredPhones.length,
        itemBuilder: (context, index) {
          final ph = filteredPhones[index];
          return InkWell(
            onTap: () {
              widget.phoneController.text = ph;
              _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ph,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        activeEntry: _phoneOverlayEntry,
        onEntryChanged: (e) => _phoneOverlayEntry = e,
      );
    } else {
      _hideOverlay(_phoneOverlayEntry, () => _phoneOverlayEntry = null);
    }
  }

  void _showSuggestionOverlay({
    required LayerLink link,
    required double width,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    required OverlayEntry? activeEntry,
    required ValueSetter<OverlayEntry?> onEntryChanged,
  }) {
    activeEntry?.remove();

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          offset: const Offset(0.0, 52.0),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
          ),
        ),
      ),
    );

    onEntryChanged(entry);
    Overlay.of(context).insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    final nameDecoration = widget.isCustomDecoration
        ? CustomDecoration.uInputDecoration(
            labelText: 'Customer Name *',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search, size: 20),
              onPressed: () {},
            ),
          )
        : const InputDecoration(
            labelText: 'Customer Name *',
            suffixIcon: Icon(Icons.search),
          );

    final addressDecoration = widget.isCustomDecoration
        ? CustomDecoration.uInputDecoration(labelText: 'Address')
        : const InputDecoration(labelText: 'Address');

    final phoneDecoration = widget.isCustomDecoration
        ? CustomDecoration.uInputDecoration(labelText: 'Phone Number')
        : const InputDecoration(labelText: 'Phone Number');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            _nameWidth = constraints.maxWidth;
            return CompositedTransformTarget(
              link: _nameLayerLink,
              child: TextFormField(
                controller: widget.nameController,
                focusNode: _nameFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: nameDecoration,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            );
          },
        ),
        if (widget.showExtraFields) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _addressWidth = constraints.maxWidth;
                    return CompositedTransformTarget(
                      link: _addressLayerLink,
                      child: TextFormField(
                        controller: widget.addressController,
                        focusNode: _addressFocusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: addressDecoration,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _phoneWidth = constraints.maxWidth;
                    return CompositedTransformTarget(
                      link: _phoneLayerLink,
                      child: TextFormField(
                        controller: widget.phoneController,
                        focusNode: _phoneFocusNode,
                        keyboardType: TextInputType.phone,
                        validator: UValidator.validatePhoneNumber,
                        decoration: phoneDecoration,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
