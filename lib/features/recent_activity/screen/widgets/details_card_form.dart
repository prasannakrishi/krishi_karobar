import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:krishi_karobar/models/models.dart';
import 'package:krishi_karobar/services/data_cache_service.dart';
import 'package:krishi_karobar/utils/theme/widget_themes/custom_decoration.dart';
import 'package:krishi_karobar/features/recent_activity/controllers/activity_controller.dart';


class DetailsCardForm extends StatefulWidget {
  const DetailsCardForm({
    super.key,
    required this.entry,
    required this.controller,
  });

  final ActivityModel entry;
  final ActivityController controller;

  @override
  State<DetailsCardForm> createState() => _DetailsCardFormState();
}

class _DetailsCardFormState extends State<DetailsCardForm> {
  late TextEditingController paidController;
  late TextEditingController dueController;
  late TextEditingController descriptionController;
  
  final FocusNode _paidFocusNode = FocusNode();
  final FocusNode _descFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initControllers();
    
    _paidFocusNode.addListener(() {
      if (!_paidFocusNode.hasFocus) {
        _handlePaidSubmitted(paidController.text);
      }
    });

    _descFocusNode.addListener(() {
      if (!_descFocusNode.hasFocus) {
        _handleDescriptionSubmitted(descriptionController.text);
      }
    });
  }

  @override
  void didUpdateWidget(DetailsCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.guid != widget.entry.guid) {
      _initControllers();
    }
  }

  void _initControllers() {
    paidController = TextEditingController(
      text: widget.entry.paidAmount > 0 ? widget.entry.paidAmount.toString() : '',
    );
    dueController = TextEditingController(
      text: widget.entry.dueAmount.toString(),
    );
    descriptionController = TextEditingController(
      text: widget.entry.description ?? '',
    );
  }

  Future<void> _handlePaidSubmitted(String value) async {
    final newPaidTotal = int.tryParse(value) ?? 0;
    
    if (newPaidTotal != widget.entry.paidAmount) {
      // १. Firebase मा अपडेट गर्ने
      await widget.controller.updatePaidStatus(widget.entry, newPaidTotal);
      
      // २. अपडेट भइसकेपछि Details Card लाई Hide गर्ने (selectedIndex = null)
      widget.controller.selectIndex(null);
    }
  }

  Future<void> _handleDescriptionSubmitted(String value) async {
    if (value != widget.entry.description) {
      widget.entry.description = value;
      widget.entry.updatedAt = DateTime.now();
      await widget.controller.firebaseService.updateRecord(
        {
          'description': value, 
          'updatedAt': widget.entry.updatedAt.toIso8601String()
        },
        'activities',
        widget.entry.guid,
      );
    }
  }

  @override
  void dispose() {
    paidController.dispose();
    dueController.dispose();
    descriptionController.dispose();
    _paidFocusNode.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color.fromARGB(255, 228, 247, 248),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: CustomDecoration.uTextField('Vehicle Number', DataCacheService.instance.getVehicleNumber(widget.entry.vehicle))),
                const SizedBox(width: 10),
                Expanded(child: CustomDecoration.uTextField('Customer Name', DataCacheService.instance.getCustomerName(widget.entry.customer))),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: CustomDecoration.uTextField('Service Type', DataCacheService.instance.getServiceName(widget.entry.serviceType))),
                const SizedBox(width: 10),
                Expanded(child: CustomDecoration.uTextField('Rate/hr', widget.entry.rate.toString())),
              ],
            ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: CustomDecoration.uTextField('Start Time', _formatEntryTime(widget.entry.createdAt, widget.entry.startTime))),
                const SizedBox(width: 10),
                Expanded(child: CustomDecoration.uTextField('End Time', _formatEntryTime(widget.entry.createdAt, widget.entry.endTime))),
                const SizedBox(width: 10),
                Expanded(child: CustomDecoration.uTextField('Duration', widget.entry.duration)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: paidController,
                      focusNode: _paidFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.right,
                      decoration: CustomDecoration.uInputDecoration(
                        labelText: 'Paid Amount',
                        prefixText: 'रु ',
                        fillColor: const Color.fromARGB(197, 78, 251, 139),
                      ),
                      onFieldSubmitted: _handlePaidSubmitted,
                      onTapOutside: (event) => _paidFocusNode.unfocus(),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextFormField(
                      controller: dueController,
                      textAlign: TextAlign.right,
                      readOnly: true,
                      decoration: CustomDecoration.uInputDecoration(
                        labelText: 'Due Amount',
                        prefixText: 'रु ',
                        fillColor: const Color.fromARGB(255, 247, 191, 191),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: descriptionController,
              focusNode: _descFocusNode,
              keyboardType: TextInputType.multiline,
              decoration: CustomDecoration.uInputDecoration(
                labelText: 'Description',
                fillColor: const Color.fromARGB(73, 249, 251, 250),
              ),
              onFieldSubmitted: _handleDescriptionSubmitted,
              onTapOutside: (event) => _descFocusNode.unfocus(),
            )
          ],
        ),
      ),
    );
  }

  String _formatEntryTime(DateTime createdAt, String time) {
    try {
      final combined = DateTime.parse('${DateFormat('yyyy-MM-dd').format(createdAt)} $time');
      return DateFormat.jm().format(combined);
    } catch (e) {
      return time;
    }
  }
}
