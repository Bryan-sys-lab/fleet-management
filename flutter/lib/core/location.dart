import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';
import 'format.dart';
import 'policy.dart';

class PhonePoint {
  PhonePoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedKph,
    this.headingDeg,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speedKph;
  final double? headingDeg;
  final double? accuracyM;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        if (speedKph != null) 'speed_kph': speedKph,
        if (headingDeg != null) 'heading_deg': headingDeg,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      };
}

/// Phone-GPS fallback sampler (D-08 is an accepted limit): it runs only while
/// the app is open. Points are buffered and flushed as bounded batches to
/// POST /telemetry/points; the server resolves the vehicle from the caller's
/// OPEN shift and never trusts a body-supplied vehicle.
class PhoneTracker {
  PhoneTracker({required this._api});

  final ApiClient _api;
  StreamSubscription<Position>? _sub;
  final List<PhonePoint> _buffer = [];
  Timer? _flushTimer;
  bool _sampling = false;
  DateTime? _lastPointAt;

  bool get isSampling => _sampling;
  int get buffered => _buffer.length;

  Future<bool> start() async {
    if (_sampling) return true;
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    _sampling = true;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: Policy.phonePositionDistanceFilterM,
      ),
    ).listen(_onPosition, onError: (_) {});
    _flushTimer ??= Timer.periodic(Policy.phoneFlushInterval, (_) {
      flush();
    });
    return true;
  }

  void _onPosition(Position position) {
    final now = DateTime.now().toUtc();
    if (_lastPointAt != null && now.difference(_lastPointAt!) < Policy.phonePointsMinInterval) {
      return; // server enforces a 10s sampling floor — don't send TOO_DENSE
    }
    _lastPointAt = now;
    // trim history to the server's 5-minute window
    _buffer.removeWhere((p) => now.difference(p.recordedAt).inSeconds > Policy.phonePointsMaxHistorySeconds);
    _buffer.add(PhonePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: now,
      speedKph: position.speed >= 0 ? position.speed * 3.6 : null,
      headingDeg: position.heading >= 0 ? position.heading : null,
      accuracyM: position.accuracy >= 0 ? position.accuracy : null,
    ));
    if (_buffer.length >= Policy.phonePointsMax) {
      flush();
    }
  }

  /// Flushes at clock-out so buffered positions are not lost.
  Future<void> flushOnStop() => flush();

  Future<bool> flush() async {
    if (_buffer.isEmpty) return true;
    final batch = _buffer.take(Policy.phonePointsMax).toList();
    try {
      await _api.write<Map<String, dynamic>>(
        'POST',
        'telemetry/points',
        body: {'points': batch.map((p) => p.toJson()).toList()},
        idempotent: false,
        parse: (b) => b as Map<String, dynamic>,
      );
      _buffer.removeRange(0, batch.length);
      return true;
    } catch (_) {
      return false; // points stay buffered; a later flush retries
    }
  }

  Future<void> stop() async {
    _sampling = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _sub?.cancel();
    _sub = null;
    await flush();
  }

  void dispose() {
    _flushTimer?.cancel();
    _sub?.cancel();
  }
}

/// One-shot current fix for Mayday: permission → last known → fresh balanced.
Future<PhonePoint?> currentFix() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
  }
  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return PhonePoint(
      latitude: position.latitude,
      longitude: position.longitude,
      recordedAt: DateTime.now().toUtc(),
      accuracyM: position.accuracy >= 0 ? position.accuracy : null,
    );
  } catch (_) {
    final last = await Geolocator.getLastKnownPosition();
    if (last == null) return null;
    return PhonePoint(
      latitude: last.latitude,
      longitude: last.longitude,
      recordedAt: DateTime.now().toUtc(),
      accuracyM: last.accuracy >= 0 ? last.accuracy : null,
    );
  }
}

/// Stable device hash used by device registration (never the raw id).
/// sha256-raw, first 32 chars — deterministic and ≥16 chars as the schema requires.
String deviceIdHashFrom(String raw) {
  final digest = sha256Hex('$raw:helix-device');
  return digest.substring(0, 32);
}
