import 'dart:async';
import '../policy.dart';

/// Drains and reschedules with exponential backoff + jitter.
/// Kicked on start, foreground, reconnect, after each submit, and manually.
class DrainScheduler {
  DrainScheduler({required this._drain, required this._arm});

  final Future<void> Function() _drain;
  final void Function(Duration) _arm;
  Timer? _timer;
  int _passes = 0;

  static Duration delayFor(int passes) {
    final base = Policy.retryBase.inMilliseconds;
    final max = Policy.retryMax.inMilliseconds;
    final delay = (base * (1 << passes.clamp(0, 10))).clamp(base, max);
    final jitter = 0.75 + (DateTime.now().microsecondsSinceEpoch % 500) / 1000; // 0.75–1.25
    return Duration(milliseconds: (delay * jitter).round());
  }

  void kick() {
    _timer?.cancel();
    _passes = 0;
    _drain().then((_) => _scheduleIfNeeded());
  }

  void arm() {
    _timer?.cancel();
    _scheduleIfNeeded();
  }

  void _scheduleIfNeeded() {
    _timer?.cancel();
    _timer = Timer(delayFor(_passes), () {
      _drain().then((_) {
        _passes += 1;
        _scheduleIfNeeded();
      });
    });
    _arm(delayFor(_passes));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
