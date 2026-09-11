import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../constants/colors.dart';


  Color? getColor(String value) {
    /// Define your product specific colors here and it will match the attribute colors and show specific 🟠🟡🟢🔵🟣🟤

    if (value == 'Green') {
      return Colors.green;
    } else if (value == 'Green') {
      return Colors.green;
    } else if (value == 'Red') {
      return Colors.red;
    } else if (value == 'Blue') {
      return Colors.blue;
    } else if (value == 'Pink') {
      return Colors.pink;
    } else if (value == 'Grey') {
      return Colors.grey;
    } else if (value == 'Purple') {
      return Colors.purple;
    } else if (value == 'Black') {
      return Colors.black;
    } else if (value == 'White') {
      return Colors.white;
    } else if (value == 'Yellow') {
      return Colors.yellow;
    } else if (value == 'Orange') {
      return Colors.deepOrange;
    } else if (value == 'Brown') {
      return Colors.brown;
    } else if (value == 'Teal') {
      return Colors.teal;
    } else if (value == 'Indigo') {
      return Colors.indigo;
    } else {
      return null;
    }
  }

  void customToast({required String message}){
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      SnackBar(
        elevation: 0,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(12.0),
          margin: const EdgeInsets.symmetric(horizontal: 30.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isDarkMode(Get.context!) ? UColors.darkerGrey : UColors.grey
          ),
          child: Center(child: Text(message,style: Theme.of(Get.context!).textTheme.labelLarge,),),
        ),
      )
    );
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(Get.context!).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showAlert(String title, String message) {
    showDialog(
      context: Get.context!,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void warningSnackBar({required String title, String message = ''}){
    Get.snackbar(
        title,
        message,
        isDismissible: true,
        shouldIconPulse: true,
        colorText: UColors.white,
        backgroundColor: Colors.orange,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        icon: const Icon(Iconsax.warning_2,color: UColors.white,)
    );
  }

  void successSnackBar({required String title, String message = '', int duration = 10}){
    Get.snackbar(
        title,
        message,
      isDismissible: true,
      shouldIconPulse: true,
      colorText: UColors.white,
      backgroundColor: UColors.primary,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: duration),
      margin: const EdgeInsets.all(10),
      icon: const Icon(Iconsax.check,color: UColors.white,)
    );
  }

  void errorSnackBar({required String title, String message = ''}){
    Get.snackbar(
        title,
        message,
      isDismissible: true,
      shouldIconPulse: true,
      colorText: UColors.white,
      backgroundColor: Colors.red.shade600,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 10),
      margin: const EdgeInsets.all(20),
      icon: const Icon(Iconsax.warning_2, color: UColors.white,)
    );
  }

  void navigateToScreen(BuildContext context, Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    } else {
      return '${text.substring(0, maxLength)}...';
    }
  }

  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Size screenSize() {
    return MediaQuery.of(Get.context!).size;
  }

  double screenHeight() {
    return MediaQuery.of(Get.context!).size.height;
  }

  double screenWidth() {
    return MediaQuery.of(Get.context!).size.width;
  }

  List<Widget> wrapWidgets(List<Widget> widgets, int rowSize) {
    final wrappedList = <Widget>[];
    for (var i = 0; i < widgets.length; i += rowSize) {
      final rowChildren = widgets.sublist(i, i + rowSize > widgets.length ? widgets.length : i + rowSize);
      wrappedList.add(Row(children: rowChildren));
    }
    return wrappedList;
  }

  Widget datePicker({
    required String label,
    required BuildContext context,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2020),
              lastDate: DateTime(2050),
            );
            if (picked != null) {
              final withTime = DateTime(
                picked.year,
                picked.month,
                picked.day,
                now.hour,
                now.minute,
              );
              controller.text = DateFormat('yyyy-MM-dd HH:mm').format(withTime);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              controller.text.isNotEmpty
                  ? controller.text
                  : DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget floatingDropdown<T>({
    required List<T> items,
    Widget Function(T item)? leadingBuilder,
    required Widget Function(T item) titleBuilder,
    Widget Function(T item)? subtitleBuilder,
    required void Function(T item) onTap,
    VoidCallback? onClose,
    double top = 50,
    double listHeight = 220,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: top,
      left: 10,
      right: 10,
      child: Material(
        elevation: 12,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200, width: 1),
          ),
          constraints: BoxConstraints(maxHeight: listHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      leading: leadingBuilder != null ? leadingBuilder(item) : null,
                      title: titleBuilder(item),
                      subtitle: subtitleBuilder != null ? subtitleBuilder(item) : null,
                      onTap: () => onTap(item),
                    );
                  },
                  separatorBuilder: (_, _) => const Divider(height: 1, indent: 15, endIndent: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget selectedTab({
    required String label,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.lightGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 18,
            color: isSelected ? Colors.black87 : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  Widget uDataTable({
    required List<Widget> columns,
    required List<List<Widget>> rowValues,
    int? selectedIndex,
    void Function(int? index)? onRowSelect,
  }) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 2,
          horizontalMargin: 1,
          headingRowHeight: 25,

          columns: columns.map((c) => DataColumn(label: c)).toList(),
          rows: List.generate(rowValues.length, (rowIndex) {
            final selected = selectedIndex == rowIndex;
            return DataRow(
              selected: selected,
              onSelectChanged: (v) {
                if (onRowSelect != null) {
                  onRowSelect(selected ? null : rowIndex);
                }
              },
              cells: rowValues[rowIndex].map((widget) => DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 1),
                  child: widget,
                ),
              )).toList(),
            );
          }),
        ),
      ),
    );
  }


class MarqueeWidget extends StatefulWidget {
  final Widget child;
  const MarqueeWidget({super.key, required this.child});

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _startScrolling() async {
    while (mounted && _scrollController.hasClients) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted && _scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 3),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (mounted && _scrollController.hasClients) {
          await _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: widget.child,
    );
  }
}

