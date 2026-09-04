


import 'package:flutter/cupertino.dart';
import '../../utils/constants/colors.dart';

class UShadowStyle{

  static final verticalProductShadow = BoxShadow(
    color: UColors.darkGrey,
    blurRadius: 50,
    spreadRadius: 7,
    offset: const Offset(0, 2)
  );

  static final horizontalProductShadow = BoxShadow(
      color: UColors.darkGrey,
      blurRadius: 50,
      spreadRadius: 7,
      offset: const Offset(0, 2)
  );
}