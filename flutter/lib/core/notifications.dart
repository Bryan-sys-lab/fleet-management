import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications rendered from gateway events (no FCM — decision P-06).
/// Lock-screen hides content; the durable record is the inbox.
class LocalNotifications {
  LocalNotifications._();
  static final LocalNotifications instance = LocalNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _ready = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'helix_events',
        'Fleet events',
        channelDescription: 'Accidents, shifts and fleet alerts',
        importance: Importance.high,
        visibility: NotificationVisibility.private, // lock screen hides content
      ),
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }
}
