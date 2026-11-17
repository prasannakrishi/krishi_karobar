import 'package:flutter/material.dart';

/// Fixed-width, single-line marquee cell used by every `uDataTable`
/// screen (Recent Activity, sync status).
Widget uTableCell(Widget child, double width) {
  return SizedBox(
    width: width,
    height: 30,
    child: MarqueeWidget(
      child: child,
    ),
  );
}

Widget uDataTable({
  required List<Widget> columns,
  required List<List<Widget>> rowValues,
  int? selectedIndex,
  void Function(int? index)? onRowSelect,
  void Function(int index)? onRowLongPress,
  void Function(int index, TapUpDetails details)? onRowSecondaryTap,
}) {
  return UDataTableWidget(
    columns: columns,
    rowValues: rowValues,
    onRowSelect: onRowSelect,
    onRowLongPress: onRowLongPress,
    onRowSecondaryTap: onRowSecondaryTap,
  );
}

class UDataTableWidget extends StatefulWidget {
  const UDataTableWidget({
    super.key,
    required this.columns,
    required this.rowValues,
    this.selectedIndex,
    this.onRowSelect,
    this.onRowLongPress,
    this.onRowSecondaryTap,
  });

  final List<Widget> columns;
  final List<List<Widget>> rowValues;
  final int? selectedIndex;
  final void Function(int? index)? onRowSelect;
  final void Function(int index)? onRowLongPress;
  final void Function(int index, TapUpDetails details)? onRowSecondaryTap;

  @override
  State<UDataTableWidget> createState() => _UDataTableWidgetState();
}

class _UDataTableWidgetState extends State<UDataTableWidget> {
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _bodyHorizontalController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController.addListener(_syncHeaderToBody);
    _bodyHorizontalController.addListener(_syncBodyToHeader);
  }

  void _syncHeaderToBody() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    if (_bodyHorizontalController.hasClients) {
      _bodyHorizontalController.jumpTo(_headerHorizontalController.offset);
    }
    _isSyncingScroll = false;
  }

  void _syncBodyToHeader() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    if (_headerHorizontalController.hasClients) {
      _headerHorizontalController.jumpTo(_bodyHorizontalController.offset);
    }
    _isSyncingScroll = false;
  }

  @override
  void dispose() {
    _headerHorizontalController.removeListener(_syncHeaderToBody);
    _bodyHorizontalController.removeListener(_syncBodyToHeader);
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final header = SingleChildScrollView(
          controller: _headerHorizontalController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 2,
              horizontalMargin: 0,
              headingRowHeight: 25,
              dataRowMaxHeight: 0,
              dataRowMinHeight: 0,
              columns: widget.columns.map((c) => DataColumn(label: c)).toList(),
              rows: const [],
            ),
          ),
        );

        final bodyContent = SingleChildScrollView(
          controller: _bodyHorizontalController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SingleChildScrollView(
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: 2,
                horizontalMargin: 0,
                headingRowHeight: 0,
                dataRowMaxHeight: 38.0,
                dataRowMinHeight: 30.0,
                columns: widget.columns
                    .map((c) => DataColumn(
                          label: SizedBox(
                            width: 0,
                            height: 0,
                            child: Visibility(
                              visible: false,
                              maintainSize: true,
                              maintainAnimation: true,
                              maintainState: true,
                              child: c,
                            ),
                          ),
                        ))
                    .toList(),
                rows: List.generate(widget.rowValues.length, (rowIndex) {
                  final selected = widget.selectedIndex == rowIndex;
                  return DataRow(
                    selected: selected,
                    onSelectChanged: (v) {
                      if (widget.onRowSelect != null) {
                        widget.onRowSelect!(selected ? null : rowIndex);
                      }
                    },
                    cells: widget.rowValues[rowIndex]
                        .map((cellWidget) => DataCell(
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onLongPress: widget.onRowLongPress != null
                                    ? () => widget.onRowLongPress!(rowIndex)
                                    : null,
                                onSecondaryTapUp: widget.onRowSecondaryTap != null
                                    ? (details) =>
                                        widget.onRowSecondaryTap!(rowIndex, details)
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 2, horizontal: 1),
                                  child: cellWidget,
                                ),
                              ),
                            ))
                        .toList(),
                  );
                }),
              ),
            ),
          ),
        );

        if (constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              Expanded(child: bodyContent),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: bodyContent,
              ),
            ],
          );
        }
      },
    );
  }
}

class MarqueeWidget extends StatefulWidget {
  final Widget child;

  const MarqueeWidget({required this.child, super.key});

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      if (!_isScrolling) {
        _isScrolling = true;
        _startScroll();
      }
    }
  }

  void _startScroll() async {
    while (_isScrolling && mounted) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isScrolling || !mounted || !_scrollController.hasClients) break;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) break;

      try {
        await _scrollController.animateTo(
          max,
          duration: Duration(milliseconds: (max * 30).toInt().clamp(1000, 5000)),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (!_isScrolling || !mounted || !_scrollController.hasClients) break;
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOut,
        );
      } catch (_) {
        break;
      }
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: widget.child,
    );
  }
}
