import 'dart:ui';
import 'package:flutter/material.dart';
import '../../utils/constants/background_config.dart';
import '../../utils/constants/colors.dart';

class UAppScaffold extends StatelessWidget {
  const UAppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        _background(),
        if (UBackgroundConfig.blur > 0) _blur(),
        _overlay(isDark),
        Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          appBar: appBar,
          body: body,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        ),
      ],
    );
  }

  Widget _background() {
    if (!UBackgroundConfig.useImage) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              UColors.primaryLight,
              UColors.light,
              UColors.secondaryLight,
            ],
          ),
        ),
      );
    }

    return Opacity(
      opacity: UBackgroundConfig.imageOpacity,
      child: Image.asset(UBackgroundConfig.image, fit: BoxFit.cover),
    );
  }

  Widget _blur() {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: UBackgroundConfig.blur,
        sigmaY: UBackgroundConfig.blur,
      ),
      child: const SizedBox.expand(),
    );
  }

  Widget _overlay(bool isDark) {
    return Container(
      color:
          (isDark
                  ? UBackgroundConfig.darkOverlay
                  : UBackgroundConfig.lightOverlay)
              .withValues(alpha: UBackgroundConfig.overlayOpacity),
    );
  }
}
