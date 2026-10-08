import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'u_display_size.dart';

class UOption<T> {
  final T value;
  final String label;
  final String? subtitle;

  const UOption({
    required this.value,
    required this.label,
    this.subtitle,
  });
}

class UOptionField<T> extends StatefulWidget {
  const UOptionField({
    super.key,
    required this.options,
    this.value,
    this.selectedValues,
    this.labelText,
    this.hintText = 'Select option',
    this.required = false,
    this.multiOption = false,
    this.multiLineOption = false,
    this.searchable = false,
    this.enabled = true,
    this.onChanged,
    this.onMultiChanged,
    this.validator,
    this.displaySize,
  });

  final List<UOption<T>> options;
  final T? value;
  final List<T>? selectedValues;
  final String? labelText;
  final String hintText;
  final bool required;
  final bool multiOption;
  final bool multiLineOption;
  final bool searchable;
  final bool enabled;
  final ValueChanged<T?>? onChanged;
  final ValueChanged<List<T>>? onMultiChanged;
  final String? Function(dynamic)? validator;
  final UDisplaySize? displaySize;

  @override
  State<UOptionField<T>> createState() => _UOptionFieldState<T>();
}

class _UOptionFieldState<T> extends State<UOptionField<T>> {
  T? _singleValue;
  late List<T> _multiValues;

  @override
  void initState() {
    super.initState();
    _singleValue = widget.value;
    _multiValues = widget.selectedValues != null ? List<T>.from(widget.selectedValues!) : <T>[];
  }

  @override
  void didUpdateWidget(covariant UOptionField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _singleValue = widget.value;
    }
    if (widget.selectedValues != oldWidget.selectedValues && widget.selectedValues != null) {
      _multiValues = List<T>.from(widget.selectedValues!);
    }
  }

  void _openOptionPicker(BuildContext context, UDisplaySize size) {
    if (!widget.enabled) return;

    if (widget.multiOption) {
      _openMultiSelectDialog(context, size);
    } else if (widget.searchable) {
      _openSearchableSingleDialog(context, size);
    }
  }

  void _openMultiSelectDialog(BuildContext context, UDisplaySize size) {
    final tempSelected = List<T>.from(_multiValues);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOptions = widget.searchable && searchQuery.trim().isNotEmpty
                ? widget.options.where((o) => o.label.toLowerCase().contains(searchQuery.trim().toLowerCase())).toList()
                : widget.options;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
              title: Text(widget.labelText ?? 'Select Options', style: TextStyle(fontSize: size.fontSize + 2, fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.searchable) ...[
                      TextField(
                        style: TextStyle(fontSize: size.fontSize),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          prefixIcon: Icon(Icons.search, size: size.iconSize),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final opt = filteredOptions[index];
                          final isSelected = tempSelected.contains(opt.value);

                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            title: Text(
                              opt.label,
                              style: TextStyle(fontSize: size.fontSize),
                              maxLines: widget.multiLineOption ? null : 2,
                              overflow: widget.multiLineOption ? null : TextOverflow.ellipsis,
                            ),
                            subtitle: opt.subtitle != null
                                ? Text(opt.subtitle!, style: TextStyle(fontSize: size.labelSize, color: Colors.grey))
                                : null,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  tempSelected.add(opt.value);
                                } else {
                                  tempSelected.remove(opt.value);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _multiValues = tempSelected;
                    });
                    widget.onMultiChanged?.call(_multiValues);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openSearchableSingleDialog(BuildContext context, UDisplaySize size) {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredOptions = searchQuery.trim().isNotEmpty
                ? widget.options.where((o) => o.label.toLowerCase().contains(searchQuery.trim().toLowerCase())).toList()
                : widget.options;

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
              title: Text(widget.labelText ?? 'Select Option', style: TextStyle(fontSize: size.fontSize + 2, fontWeight: FontWeight.bold)),
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      style: TextStyle(fontSize: size.fontSize),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search, size: size.iconSize),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredOptions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final opt = filteredOptions[index];
                          final isSelected = _singleValue == opt.value;

                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            title: Text(
                              opt.label,
                              style: TextStyle(fontSize: size.fontSize, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                              maxLines: widget.multiLineOption ? null : 2,
                              overflow: widget.multiLineOption ? null : TextOverflow.ellipsis,
                            ),
                            subtitle: opt.subtitle != null
                                ? Text(opt.subtitle!, style: TextStyle(fontSize: size.labelSize, color: Colors.grey))
                                : null,
                            trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).primaryColor, size: size.iconSize) : null,
                            onTap: () {
                              setState(() {
                                _singleValue = opt.value;
                              });
                              widget.onChanged?.call(_singleValue);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _displayDisplayText {
    if (widget.multiOption) {
      if (_multiValues.isEmpty) return widget.hintText;
      final selectedLabels = widget.options
          .where((o) => _multiValues.contains(o.value))
          .map((o) => o.label)
          .join(', ');
      return selectedLabels.isNotEmpty ? selectedLabels : widget.hintText;
    } else {
      if (_singleValue == null) return widget.hintText;
      final found = widget.options.firstWhereOrNull((o) => o.value == _singleValue);
      return found?.label ?? widget.hintText;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = widget.displaySize ?? UDisplaySizeController.instance.displaySize.value;

      final labelWidget = widget.labelText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.labelText!, style: TextStyle(fontSize: size.labelSize)),
                if (widget.required) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            )
          : null;

      // If non-multi and non-searchable, standard DropdownButtonFormField
      if (!widget.multiOption && !widget.searchable) {
        return DropdownButtonFormField<T>(
          initialValue: _singleValue,
          isExpanded: true,
          decoration: InputDecoration(
            label: labelWidget,
            hintText: widget.hintText,
            contentPadding: size.fieldPadding,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(size.borderRadius),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          items: widget.options.map((opt) {
            return DropdownMenuItem<T>(
              value: opt.value,
              child: Text(
                opt.label,
                style: TextStyle(fontSize: size.fontSize),
                maxLines: widget.multiLineOption ? null : 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: widget.enabled
              ? (val) {
                  setState(() => _singleValue = val);
                  widget.onChanged?.call(val);
                }
              : null,
          validator: (val) => widget.validator?.call(val),
        );
      }

      // Dialog or picker based for multi-option or searchable options
      return FormField<dynamic>(
        validator: widget.validator,
        builder: (fieldState) {
          final isHasError = fieldState.hasError;

          return InkWell(
            onTap: widget.enabled ? () => _openOptionPicker(context, size) : null,
            borderRadius: BorderRadius.circular(size.borderRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                label: labelWidget,
                hintText: widget.hintText,
                contentPadding: size.fieldPadding,
                isDense: true,
                errorText: fieldState.errorText,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(size.borderRadius)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(size.borderRadius),
                  borderSide: BorderSide(color: isHasError ? Colors.red : Colors.grey.shade300),
                ),
                suffixIcon: Icon(
                  widget.multiOption ? Icons.filter_list : Icons.arrow_drop_down,
                  size: size.iconSize,
                ),
              ),
              child: Text(
                _displayDisplayText,
                style: TextStyle(
                  fontSize: size.fontSize,
                  color: (_multiOptionHasValue || _singleValue != null) ? Colors.black87 : Colors.grey.shade500,
                ),
                maxLines: widget.multiLineOption ? null : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      );
    });
  }

  bool get _multiOptionHasValue => widget.multiOption && _multiValues.isNotEmpty;
}
