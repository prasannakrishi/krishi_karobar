import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'u_display_size.dart';

class UTextField extends StatefulWidget {
  const UTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.required = false,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.showClearButton = false,
    this.searchable = false,
    this.suggestions = const [],
    this.displaySize,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final bool required;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final VoidCallback? onTap;
  final bool showClearButton;
  final bool searchable;
  final List<String> suggestions;
  final UDisplaySize? displaySize;

  @override
  State<UTextField> createState() => _UTextFieldState();
}

class _UTextFieldState extends State<UTextField> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  List<String> _buildFilteredSuggestions(String query) {
    if (widget.suggestions.isEmpty) return const [];
    final cleanQuery = query.trim().toLowerCase();
    final seen = <String>{};

    final startsWithMatches = <String>[];
    final containsMatches = <String>[];

    for (final item in widget.suggestions) {
      final cleanItem = item.trim();
      if (cleanItem.isEmpty || !seen.add(cleanItem.toLowerCase())) continue;

      final lowerItem = cleanItem.toLowerCase();
      if (cleanQuery.isEmpty) {
        startsWithMatches.add(cleanItem);
      } else if (lowerItem.startsWith(cleanQuery)) {
        startsWithMatches.add(cleanItem);
      } else if (lowerItem.contains(cleanQuery)) {
        containsMatches.add(cleanItem);
      }
    }

    final combined = [...startsWithMatches, ...containsMatches];
    return combined.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final size = widget.displaySize ?? UDisplaySizeController.instance.displaySize.value;

      Widget? suffix;
      if (widget.showClearButton && _effectiveController.text.isNotEmpty && !widget.readOnly && widget.enabled) {
        suffix = IconButton(
          icon: Icon(Icons.clear, size: size.iconSize, color: Colors.grey),
          onPressed: () {
            _effectiveController.clear();
            widget.onChanged?.call('');
            setState(() {});
          },
        );
      } else {
        suffix = widget.suffixIcon;
      }

      Widget field;

      if (widget.searchable) {
        field = RawAutocomplete<String>(
          focusNode: _effectiveFocusNode,
          textEditingController: _effectiveController,
          optionsBuilder: (TextEditingValue textEditingValue) {
            return _buildFilteredSuggestions(textEditingValue.text);
          },
          onSelected: (String selection) {
            _effectiveController.text = selection;
            _effectiveController.selection = TextSelection.collapsed(offset: selection.length);
            widget.onChanged?.call(selection);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return _buildTextFormField(
              size: size,
              controller: controller,
              focusNode: focusNode,
              suffix: suffix,
              onSubmitted: (_) => onSubmitted(),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                borderRadius: BorderRadius.circular(size.borderRadius),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        dense: true,
                        title: Text(
                          option,
                          style: TextStyle(fontSize: size.fontSize),
                        ),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      } else {
        field = _buildTextFormField(
          size: size,
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          suffix: suffix,
          onSubmitted: widget.onFieldSubmitted,
        );
      }

      return field;
    });
  }

  Widget _buildTextFormField({
    required UDisplaySize size,
    required TextEditingController controller,
    required FocusNode focusNode,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    final labelWidget = widget.labelText != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.labelText!,
                style: TextStyle(fontSize: size.labelSize),
              ),
              if (widget.required)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          )
        : null;

    final inputDecoration = InputDecoration(
      label: labelWidget,
      hintText: widget.hintText,
      hintStyle: TextStyle(fontSize: size.fontSize, color: Colors.grey.shade400),
      prefixIcon: widget.prefixIcon,
      suffixIcon: suffix,
      prefixText: widget.prefixText,
      suffixText: widget.suffixText,
      contentPadding: size.fieldPadding,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(size.borderRadius),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(size.borderRadius),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(size.borderRadius),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
      ),
    );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: widget.keyboardType,
      obscureText: widget.obscureText,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      textCapitalization: widget.textCapitalization,
      style: TextStyle(fontSize: size.fontSize),
      decoration: inputDecoration,
      validator: widget.validator,
      onChanged: (val) {
        if (widget.showClearButton) setState(() {});
        widget.onChanged?.call(val);
      },
      onFieldSubmitted: onSubmitted,
      onTap: widget.onTap,
    );
  }
}
