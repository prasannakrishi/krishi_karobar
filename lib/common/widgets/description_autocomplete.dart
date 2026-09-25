import 'package:flutter/material.dart';

class DescriptionAutocomplete extends StatefulWidget {
  const DescriptionAutocomplete({
    super.key,
    required this.controller,
    required this.recentDescriptions,
    this.decoration,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final List<String> recentDescriptions;
  final InputDecoration? decoration;
  final int maxLines;

  @override
  State<DescriptionAutocomplete> createState() => _DescriptionAutocompleteState();
}

class _DescriptionAutocompleteState extends State<DescriptionAutocomplete> {
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
        final suggestions = widget.recentDescriptions;
        final query = textEditingValue.text.trim().toLowerCase();

        if (query.isEmpty) {
          return suggestions;
        }

        return suggestions.where(
          (desc) => desc.toLowerCase().contains(query),
        );
      },
      onSelected: (String selection) {
        widget.controller.text = selection;
        widget.controller.selection = TextSelection.collapsed(
          offset: selection.length,
        );
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        final defaultDeco = InputDecoration(
          labelText: 'Description',
          hintText: 'Type or select previous description',
          suffixIcon: PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down),
            tooltip: 'Previous Descriptions',
            onSelected: (String value) {
              widget.controller.text = value;
              widget.controller.selection =
                  TextSelection.collapsed(offset: value.length);
            },
            itemBuilder: (BuildContext context) {
              final suggestions = widget.recentDescriptions;
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
        );

        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          maxLines: widget.maxLines,
          decoration: widget.decoration ?? defaultDeco,
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
