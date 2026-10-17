import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../core/kv_store.dart';
import '../core/session.dart';
import '../core/clerk_service.dart';
import '../core/clerk_config.dart';
import '../core/api_client.dart';
import '../core/offline/queue.dart';
import '../core/media.dart';
import '../core/connectivity.dart';
import '../core/location.dart';
import '../core/offline/drain_scheduler.dart';

/// Composition root: wires SessionService → ClerkService → ApiClient →
/// OfflineQueue → MediaService. Holds the shared service instances so screens
/// can reach them through Riverpod providers.
class AppContainer {
  AppContainer._({
    required this.session,
    required this.api,
    required this.queue,
    required this.media,
    required this.connectivity,
    required this.phoneTracker,
    required this.scheduler,
  });

  /// Session state machine (auth, PIN, consent, shell).
  final SessionService session;

  /// HTTP client with bearer token, idempotency, 401 replay.
  final ApiClient api;

  /// Offline write queue (serial, idempotent drain).
  final OfflineQueue queue;

  /// Media pipeline (resize → stage → presign → PUT).
  final MediaService media;

  /// Online/offline probe.
  final ConnectivityService connectivity;

  /// Phone-GPS fallback sampler.
  final PhoneTracker phoneTracker;

  /// Queue drain scheduler with backoff + jitter.
  final DrainScheduler scheduler;

  static Future<AppContainer> create(SharedPreferences prefs) async {
    final store = MemoryKeyValueStore();
    final clerkConfig = ClerkConfig.fromEnv();
    final clerk = ClerkService(config: clerkConfig);

    final session = SessionService(store: store, clerk: clerk);

    final api = ApiClient(
      accessToken: () async => session.accessToken,
      refreshTokens: () => session.refreshIfNeeded(),
      onAuthLost: () => session.signOut(),
    );

    session.attachApi(api);

    final db = await _openDatabase();
    final queueStore = await OfflineQueueStore.open(db);

    final mediaService = MediaService(api: api);

    final queue = OfflineQueue(
      store: queueStore,
      api: api,
      uploadStaged: (upload) => mediaService.uploadStaged(upload),
      onDone: (_) {},
      refreshIfNeeded: () => session.refreshIfNeeded(),
      isOnline: () => Future.value(true),
    );

    Future<void> drainClosure() => queue.drain();
    final connectivity = ConnectivityService();
    final phoneTracker = PhoneTracker(api: api);
    final scheduler = DrainScheduler(
      drain: drainClosure,
      arm: (_) {},
    );

    return AppContainer._(
      session: session,
      api: api,
      queue: queue,
      media: mediaService,
      connectivity: connectivity,
      phoneTracker: phoneTracker,
      scheduler: scheduler,
    );
  }

  static Future<Database> _openDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/queue.db';
    return await openDatabase(path, version: 1);
  }
}

/// Riverpod provider exposing the composition root to screens.
/// Must be overridden at app bootstrap via overrideWithValue.
final containerProvider = Provider<AppContainer>((ref) {
  throw UnimplementedError('containerProvider must be overridden at app bootstrap');
});
