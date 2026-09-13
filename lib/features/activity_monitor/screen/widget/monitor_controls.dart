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
                      'SAVE',
                      Icons.save,
                      controller.saveActivity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _button(
                      context,
                      'RESET',
                      Icons.refresh,
                      controller.confirmReset,
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
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
