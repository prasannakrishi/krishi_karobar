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

          // Someone else started this activity - view only, no controls
          // (spec sections 6/17: UI hiding is reinforced by
          // Authz.canControlActivity on every action too).
          if (live != null && !controller.isController) {
            return _ViewOnlyBanner(startedBy: controller.startedByName(live));
          }

          // THE FIX: derive "nothing is running" directly from the fresh
          // cache-backed liveActivity, not from timerController.state.
          // liveActivity updates the instant Firebase reports the activity
          // as no longer live; timerController.state is only a manually
          // managed mirror of that (reset by _onActivitiesCacheChanged) -
          // if that side effect is ever a beat late, a viewer would
          // otherwise stay stuck seeing PAUSE/STOP after the controller
          // has already completed the activity.
          if (live == null) {
            return _button(
              context,
              'START',
              Icons.play_arrow,
              controller.startActivity,
            );
          }

          switch (controller.timerController.state.value) {
            case TimerState.initial:
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
