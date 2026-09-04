import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../utils/constants/enums.dart';

class TimerController extends GetxController {
  late Timer timer;
  int elapsedTime = 0;

  final Rx<TimerState> state = TimerState.initial.obs;
  DateTime? startTime;
  DateTime? endTime;
  Duration accumulated = Duration.zero;

  final RxString duration = ''.obs;
  final RxString amount = ''.obs;
  final RxInt elapsedTimeRx = 0.obs;
  final RxString startTimeStr = ''.obs;
  final RxString endTimeStr = ''.obs;

  // For compatibility with any legacy code that might use notifiers
  final ValueNotifier<String> durationNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> amountNotifier = ValueNotifier<String>('');
  final ValueNotifier<TimerState> stateNotifier = ValueNotifier<TimerState>(TimerState.initial);
  final ValueNotifier<String> startTimeNotifier = ValueNotifier<String>('');
  final ValueNotifier<String> endTimeNotifier = ValueNotifier<String>('');

  TimerController() {
    setupTimer();
  }

  void _syncNotifiers() {
    durationNotifier.value = duration.value;
    amountNotifier.value = amount.value;
    stateNotifier.value = state.value;
    startTimeNotifier.value = startTimeStr.value;
    endTimeNotifier.value = endTimeStr.value;
  }

  String get formattedDuration {
    final dur = Duration(milliseconds: elapsedTime);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(dur.inHours);
    final minutes = twoDigits(dur.inMinutes.remainder(60));
    final seconds = twoDigits(dur.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void computeAmount(int ratePerHour) {
    final int ms = computeElapsedMilliseconds();
    final int hours = ms ~/ 3600000;
    final int minutes = (ms % 3600000) ~/ 60000;
    final int seconds = (ms % 60000) ~/ 1000;
    
    duration.value = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    final double hoursDecimal = ms / 3600000.0;
    final double amountDouble = hoursDecimal * ratePerHour;
    final int amountInt = (amountDouble + 4) ~/ 5 * 5; // round to nearest 5
    amount.value = amountInt.toString();
    _syncNotifiers();
  }

  int computeElapsedMilliseconds() {
    final int acc = accumulated.inMilliseconds;
    final int sinceStart = (state.value == TimerState.running && startTime != null)
        ? DateTime.now().difference(startTime!).inMilliseconds
        : 0;
    return acc + sinceStart;
  }

  void start() {
    if (state.value == TimerState.initial || state.value == TimerState.stopped) {
      accumulated = Duration.zero;
      elapsedTime = 0;
      startTime = DateTime.now();
      startTimeStr.value = formatDateTime(startTime!);
      endTime = null;
      endTimeStr.value = '';
    } else if (state.value == TimerState.paused) {
      startTime = DateTime.now();
    }

    state.value = TimerState.running;
    _syncNotifiers();
  }

  void pause() {
    if (state.value == TimerState.running && startTime != null) {
      accumulated += DateTime.now().difference(startTime!);
      startTime = null;
      elapsedTime = accumulated.inMilliseconds;
      elapsedTimeRx.value = elapsedTime;
      duration.value = formatTime(elapsedTime);
      state.value = TimerState.paused;
      _syncNotifiers();
    }
  }

  void resume() {
    if (state.value == TimerState.paused) {
      startTime = DateTime.now();
      state.value = TimerState.running;
      _syncNotifiers();
    }
  }

  void stop() {
    if ((state.value == TimerState.running || state.value == TimerState.paused) && startTime != null) {
      accumulated += DateTime.now().difference(startTime!);
      startTime = null;
    }
    endTime = DateTime.now();
    endTimeStr.value = formatDateTime(endTime!);
    elapsedTime = accumulated.inMilliseconds;
    elapsedTimeRx.value = elapsedTime;
    duration.value = formatTime(elapsedTime);
    state.value = TimerState.stopped;
    _syncNotifiers();
  }

  void reset() {
    startTime = null;
    endTime = null;
    accumulated = Duration.zero;
    elapsedTime = 0;
    elapsedTimeRx.value = 0;
    startTimeStr.value = '';
    endTimeStr.value = '';
    duration.value = '';
    amount.value = '';
    state.value = TimerState.initial;
    _syncNotifiers();
  }

  String formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String formatTime(int milliseconds) {
    final int hours = milliseconds ~/ 3600000;
    final int minutes = (milliseconds % 3600000) ~/ 60000;
    final int seconds = (milliseconds % 60000) ~/ 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void setupTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (state.value == TimerState.running) {
        elapsedTime = computeElapsedMilliseconds();
        elapsedTimeRx.value = elapsedTime;
        duration.value = formatTime(elapsedTime);
        durationNotifier.value = duration.value;
      }
    });
  }

  @override
  void onClose() {
    timer.cancel();
    durationNotifier.dispose();
    amountNotifier.dispose();
    stateNotifier.dispose();
    startTimeNotifier.dispose();
    endTimeNotifier.dispose();
    super.onClose();
  }
}
