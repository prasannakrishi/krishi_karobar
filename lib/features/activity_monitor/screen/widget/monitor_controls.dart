import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/monitor_controller.dart';
import '../../../../../../utils/constants/enums.dart';

class MonitorControls extends GetView<MonitorController> {
  const MonitorControls({super.key});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Obx(() {
          final live = controller.liveActivity;
          final currentId = controller.currentActivityId.value;
          final hasActiveId = currentId != null && currentId.isNotEmpty;

          // Someone else started this activity - view only, no controls
          if (live != null && !controller.isController) {
            return _ViewOnlyBanner(startedBy: controller.startedByName(live));
          }

          // Show START button only if nothing is running and timer is in initial state
          if (live == null && !hasActiveId && controller.timerController.state.value == TimerState.initial) {
            return _button(
              context,
              'START',
              Icons.play_arrow,
              controller.startActivity,
            );
          }

          switch (controller.timerController.state.value) {
            case TimerState.initial:
              if (live != null || hasActiveId) {
                return Row(
                  children: [
                    Expanded(
                      child: _button(
                        context,
                        'PAUSE',
                        Icons.pause,
                        controller.pauseActivity,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _button(
                        context,
                        'STOP',
                        Icons.stop,
                        controller.stopActivity,
                      ),
                    ),
                  ],
                );
              }
              return _button(
                context,
                'START',
                Icons.play_arrow,
                controller.startActivity,
              );
            case TimerState.running:
              return Row(
                children: [
                  Expanded(
                    child: _button(
                      context,
                      'PAUSE',
                      Icons.pause,
                      controller.pauseActivity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _button(
                      context,
                      'STOP',
                      Icons.stop,
                      controller.stopActivity,
                    ),
                  ),
                ],
              );
            case TimerState.paused:
              return Row(
                children: [
                  Expanded(
                    child: _button(
                      context,
                      'RESUME',
                      Icons.play_arrow,
                      controller.resumeActivity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _button(
                      context,
                      'STOP',
                      Icons.stop,
                      controller.stopActivity,
                    ),
                  ),
                ],
              );
            case TimerState.stopped:
              return Row(
                children: [
                  Expanded(
                    child: _button(
                      context,
                      'RESET',
                      Icons.refresh,
                      controller.confirmReset,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _button(
                      context,
                      'SAVE',
                      Icons.save,
                      controller.saveActivity,
                    ),
                  ),
                ],
              );
          }
        }),
      ),
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
  const _ViewOnlyBanner({required this.startedBy});

  final String startedBy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
