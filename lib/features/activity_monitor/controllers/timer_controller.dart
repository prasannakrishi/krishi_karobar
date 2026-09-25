import 'dart:async';
import 'package:get/get.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helper/nepali_date_time.dart';

class TimerController extends GetxController {
  Timer? _timer;
  DateTime? _runningSince;

  final state = TimerState.initial.obs;
  final elapsedMilliseconds = 0.obs;
  final duration = '00:00:00'.obs;
  final amount = 0.0.obs;
  final startTimeText = ''.obs;
  final endTimeText = ''.obs;

  DateTime? startTime;
  DateTime? endTime;
  Duration accumulated = Duration.zero;

  int get durationSeconds => elapsedMilliseconds.value ~/ 1000;

  void start() {
    if (state.value != TimerState.initial &&
        state.value != TimerState.stopped) {
      return;
    }

    accumulated = Duration.zero;
    elapsedMilliseconds.value = 0;
    amount.value = 0;

    startTime = DateTime.now();
    endTime = null;
    _runningSince = startTime;

    startTimeText.value = _formatTime(startTime!);
    endTimeText.value = '';

    state.value = TimerState.running;
    _startTimer();
  }

  void pause() {
    if (state.value != TimerState.running || _runningSince == null) {
      return;
    }

    accumulated += DateTime.now().difference(_runningSince!);
    _runningSince = null;

    _updateElapsed();
    state.value = TimerState.paused;
    _stopTimer();
  }

  void resume() {
    if (state.value != TimerState.paused) return;

    _runningSince = DateTime.now();
    state.value = TimerState.running;
    _startTimer();
  }

  /// Restores timer state from a persisted Activity record (e.g. after an
  /// app restart or page refresh) so the controller can keep
  /// pausing/resuming/completing the SAME activity seamlessly.
  void rehydrate({
    required DateTime startTime,
    required Duration accumulated,
    DateTime? runningSince,
  }) {
    _stopTimer();

    this.startTime = startTime;
    this.accumulated = accumulated;
    endTime = null;
    startTimeText.value = _formatTime(startTime);
    endTimeText.value = '';

    if (runningSince != null) {
      _runningSince = runningSince;
      state.value = TimerState.running;
      _startTimer();
    } else {
      _runningSince = null;
      state.value = TimerState.paused;
    }

    _updateElapsed();
  }

  void stop() {
    if (state.value == TimerState.running && _runningSince != null) {
      accumulated += DateTime.now().difference(_runningSince!);
      _runningSince = null;
    }

    endTime = DateTime.now();
    endTimeText.value = _formatTime(endTime!);

    _updateElapsed();
    state.value = TimerState.stopped;
    _stopTimer();
  }

  void computeAmount(int ratePerHour) {
    _updateElapsed();

    final totalSeconds = elapsedMilliseconds.value / 1000;
    final billableMinutes = (totalSeconds / 60).ceil();
    final ratePerMinute = ratePerHour / 60;

    final rawAmount = billableMinutes * ratePerMinute;

    amount.value = (rawAmount / 10).round() * 10.0;
  }

  void reset() {
    _stopTimer();

    state.value = TimerState.initial;
    elapsedMilliseconds.value = 0;
    duration.value = '00:00:00';
    amount.value = 0;

    startTime = null;
    endTime = null;
    _runningSince = null;
    accumulated = Duration.zero;

    startTimeText.value = '';
    endTimeText.value = '';
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _updateElapsed(),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateElapsed() {
    final current =
        accumulated +
        (state.value == TimerState.running && _runningSince != null
            ? DateTime.now().difference(_runningSince!)
            : Duration.zero);

    elapsedMilliseconds.value = current.inMilliseconds;
    duration.value = _formatDuration(current);
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours.toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$hours:$minutes:$seconds';
  }

  String _formatTime(DateTime value) {
    return formatNepaliTime(value, pattern: 'HH:mm:ss');
  }

  @override
  void onClose() {
    _stopTimer();
    super.onClose();
  }
}
