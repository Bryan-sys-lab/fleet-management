import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'location.dart';

/// Device identity for registration (device_id_hash, label, model, OS, app).
/// The hash is stable across launches and never the raw identifier.
class DeviceInfo {
  DeviceInfo._();

  static String? _hash;

  static Future<String> deviceIdHash() async {
    if (_hash != null) return _hash!;
    final info = DeviceInfoPlugin();
    String raw;
    try {
      final android = await info.androidInfo;
      raw = 'android:${android.id}:${android.model}:${android.device}';
    } catch (_) {
      try {
        final ios = await info.iosInfo;
        raw = 'ios:${ios.identifierForVendor}:${ios.model}';
      } catch (_) {
        raw = 'unknown-device';
      }
    }
    _hash = deviceIdHashFrom(raw);
    return _hash!;
  }

  static Future<String> deviceLabel() async => 'Helix on ${await deviceModel()}';

  static Future<String> deviceModel() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return '${android.brand} ${android.model}';
  }

  static Future<String> osVersion() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return 'Android ${android.version.release}';
  }

  static Future<String> appVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }
}
