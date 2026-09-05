import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class UBottomSheetTheme {
  UBottomSheetTheme._();

  static final lightBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: UColors.lightSurface.withValues(alpha: 0.96),
    modalBackgroundColor: UColors.lightSurface.withValues(alpha: 0.96),
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );

  static final darkBottomSheetTheme = BottomSheetThemeData(
    showDragHandle: true,
    backgroundColor: UColors.darkSurface.withValues(alpha: 0.96),
    modalBackgroundColor: UColors.darkSurface.withValues(alpha: 0.96),
    constraints: const BoxConstraints(minWidth: double.infinity),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  );
}
