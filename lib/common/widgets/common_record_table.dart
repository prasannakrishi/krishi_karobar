import 'package:flutter/material.dart';
import 'u_data_table.dart';

/// Configuration for column headers in [CommonRecordTable].
class TableColumnConfig {
  const TableColumnConfig({
    required this.title,
    required this.width,
    this.alignment = Alignment.centerLeft,
    this.sortable = false,
  });

  final String title;
  final double width;
  final Alignment alignment;
  final bool sortable;
}

/// A reusable table header cell that supports displaying active filter indicators
/// (blue filter icon + blue downward chevron) when [isFiltered] is true.
class TableHeaderCell extends StatelessWidget {
  const TableHeaderCell({
    super.key,
    required this.title,
    this.isFiltered = false,
    this.onTap,
    this.alignment = Alignment.centerLeft,
  });

  final String title;
  final bool isFiltered;
  final VoidCallback? onTap;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: isFiltered ? Colors.blue.shade700 : const Color(0xFF1E293B),
    );

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            title,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isFiltered) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.filter_list,
            size: 14,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: Colors.blue.shade700,
          ),
        ],
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: Align(alignment: alignment, child: content),
      );
    }

    return Align(alignment: alignment, child: content);
  }
}

/// A unified, modular, configurable Record Table component used across all
/// record view screens (Activities, Customers, Users, Vehicles, Services, Sync Records).
class CommonRecordTable extends StatelessWidget {
  const CommonRecordTable({
    super.key,
    required this.columns,
    required this.rowValues,
    this.selectedIndex,
    this.onRowSelect,
    this.onRowLongPress,
    this.onRowSecondaryTap,
    this.isLoading = false,
    this.emptyMessage = 'No records found.',
  });

  final List<Widget> columns;
  final List<List<Widget>> rowValues;
  final int? selectedIndex;
  final void Function(int? index)? onRowSelect;
  final void Function(int index)? onRowLongPress;
  final void Function(int index, TapUpDetails details)? onRowSecondaryTap;
  final bool isLoading;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading && rowValues.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (rowValues.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return uDataTable(
      columns: columns,
      rowValues: rowValues,
      selectedIndex: selectedIndex,
      onRowSelect: onRowSelect,
      onRowLongPress: onRowLongPress,
      onRowSecondaryTap: onRowSecondaryTap,
    );
  }
}
