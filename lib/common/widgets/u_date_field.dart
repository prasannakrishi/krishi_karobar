import 'package:flutter/material.dart';
import '../../utils/helper/nepali_date_time.dart';
import 'u_display_size.dart';
import 'u_text_field.dart';

class UDateField extends StatefulWidget {
  const UDateField({
    super.key,
    this.controller,
    this.selectedDate,
    this.labelText = 'Date',
    this.hintText = 'Select Date',
    this.required = false,
    this.enabled = true,
    this.allowClear = true,
    this.firstDate,
    this.lastDate,
    this.onDateSelected,
    this.validator,
    this.displaySize,
  });

  final TextEditingController? controller;
  final DateTime? selectedDate;
  final String? labelText;
  final String hintText;
  final bool required;
  final bool enabled;
  final bool allowClear;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<DateTime?>? onDateSelected;
  final String? Function(String?)? validator;
  final UDisplaySize? displaySize;

  @override
  State<UDateField> createState() => _UDateFieldState();
}

class _UDateFieldState extends State<UDateField> {
  late TextEditingController _effectiveController;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();
    _date = widget.selectedDate;

    if (_date != null) {
      _effectiveController.text = formatNepaliDate(_date!);
    }
  }

  @override
  void didUpdateWidget(covariant UDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _date = widget.selectedDate;
      if (_date != null) {
        _effectiveController.text = formatNepaliDate(_date!);
      } else {
        _effectiveController.clear();
      }
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    if (!widget.enabled) return;

    final picked = await pickNepaliDate(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: widget.firstDate ?? DateTime(2020),
      lastDate: widget.lastDate ?? DateTime(2050),
    );

    if (picked != null) {
      setState(() {
        _date = picked;
        _effectiveController.text = formatNepaliDate(picked);
      });
      widget.onDateSelected?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return UTextField(
      controller: _effectiveController,
      labelText: widget.labelText,
      hintText: widget.hintText,
      required: widget.required,
      readOnly: true,
      enabled: widget.enabled,
      validator: widget.validator,
      onTap: _pickDate,
      displaySize: widget.displaySize,
      prefixIcon: const Icon(Icons.calendar_today, size: 18),
      showClearButton: widget.allowClear && _date != null,
      onChanged: (val) {
        if (val.isEmpty) {
          setState(() {
            _date = null;
          });
          widget.onDateSelected?.call(null);
        }
      },
    );
  }
}
