import 'package:socket_io_client/socket_io_client.dart' as io;
import 'policy.dart';
import 'config.dart';

/// Realtime client. The app LISTENS — the gateway derives rooms from the
/// Principal, so there is no subscribe event. Events invalidate query keys;
/// payloads are never written into caches.
class RealtimeService {
  RealtimeService({required this._token, required this._onEvent});

  final String _token;
  final void Function(String, dynamic) _onEvent;
  io.Socket? _socket;
  final Map<String, DateTime> _lastInvalidate = {};
  bool _connected = false;

  bool get connected => _connected;

  static const events = [
    'map:vehicle-states',
    'notifications',
    'accident:live',
    'driver:shift',
    'driver:vehicle',
    'driver:accident',
  ];

  void connect() {
    _socket?.dispose();
    final socket = io.io(
      Config.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': _token})
          .build(),
    );
    socket.onConnect((_) {
      _connected = true;
      // snapshot-on-connect: fire every key immediately
      for (final event in events) {
        _onEvent(event, const {'snapshot': true});
      }
    });
    socket.onDisconnect((_) => _connected = false);
    socket.onConnectError((_) => _connected = false);
    for (final event in events) {
      socket.on(event, (payload) {
        final now = DateTime.now();
        final last = _lastInvalidate[event];
        if (last != null && now.difference(last) < Policy.realtimeThrottle) {
          return; // throttled: the snapshot on reconnect covers the gap
        }
        _lastInvalidate[event] = now;
        _onEvent(event, payload);
      });
    }
    socket.connect();
    _socket = socket;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }
}
