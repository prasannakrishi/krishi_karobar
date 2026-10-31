import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../../utils/constants/enums.dart';
import '../../controllers/monitor_controller.dart';

class MonitorControls extends GetView<MonitorController> {
  const MonitorControls({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Obx(() {
          final isOnline = controller.isOnline;

          final live = controller.liveActivity;
          final currentId = controller.currentActivityId.value;
          final hasActiveId = currentId != null && currentId.isNotEmpty;

          // Online हुँदा मात्र live activity control restriction
          if (isOnline &&
              live != null &&
              !controller.isController) {
            return _ViewOnlyBanner(
              startedBy: controller.startedByName(live),
            );
          }

          return _buildControls(
            context,
            state: controller.timerController.state.value,
            hasActiveActivity: hasActiveId,
          );
        }),
      ),
    );
  }

  Widget _buildControls(
      BuildContext context, {
        required TimerState state,
        required bool hasActiveActivity,
      }) {
    switch (state) {
      case TimerState.initial:
        if (hasActiveActivity) {
          return _controlRow(
            context,
            firstLabel: 'PAUSE',
            firstIcon: Icons.pause,
            firstAction: controller.pauseActivity,
            secondLabel: 'STOP',
            secondIcon: Icons.stop,
            secondAction: controller.stopActivity,
          );
        }

        return _button(
          context,
          'START',
          Icons.play_arrow,
          controller.startActivity,
        );

      case TimerState.running:
        return _controlRow(
          context,
          firstLabel: 'PAUSE',
          firstIcon: Icons.pause,
          firstAction: controller.pauseActivity,
          secondLabel: 'STOP',
          secondIcon: Icons.stop,
          secondAction: controller.stopActivity,
        );

      case TimerState.paused:
        return _controlRow(
          context,
          firstLabel: 'RESUME',
          firstIcon: Icons.play_arrow,
          firstAction: controller.resumeActivity,
          secondLabel: 'STOP',
          secondIcon: Icons.stop,
          secondAction: controller.stopActivity,
        );

      case TimerState.stopped:
        return _controlRow(
          context,
          firstLabel: 'RESET',
          firstIcon: Icons.refresh,
          firstAction: controller.confirmReset,
          secondLabel: 'SAVE',
          secondIcon: Icons.save,
          secondAction: controller.saveActivity,
        );
    }
  }

  Widget _controlRow(
      BuildContext context, {
        required String firstLabel,
        required IconData firstIcon,
        required VoidCallback firstAction,
        required String secondLabel,
        required IconData secondIcon,
        required VoidCallback secondAction,
      }) {
    return Row(
      children: [
        Expanded(
          child: _button(
            context,
            firstLabel,
            firstIcon,
            firstAction,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _button(
            context,
            secondLabel,
            secondIcon,
            secondAction,
          ),
        ),
      ],
    );
  }

  Widget _button(
      BuildContext context,
      String label,
      IconData icon,
      VoidCallback onPressed,
      ) {
    return ElevatedButton.icon(
      onPressed: controller.isLoading.value ? null : onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ViewOnlyBanner extends StatelessWidget {
  const _ViewOnlyBanner({
    required this.startedBy,
  });

  final String startedBy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You are viewing this activity. Only $startedBy '
                  '(who started it) can control it.',
            ),
          ),
        ],
      ),
    );
  }
}