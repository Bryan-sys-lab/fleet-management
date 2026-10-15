import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Online/offline probe. Boots optimistic; the first result corrects it.
class ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  final _connectivity = Connectivity();
  bool _online = true;

  bool get isOnline => _online;
  Stream<bool> get changes => _controller.stream;

  Future<void> init() async {
    final results = await _connectivity.checkConnectivity();
    _apply(results);
    _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      _controller.add(online);
    }
  }

  void dispose() => _controller.close();
}
