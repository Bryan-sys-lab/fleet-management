import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'kv_store.dart';

export 'kv_store.dart' show StoreKeys;

/// Secure key-value storage for tokens, PIN material and consent records.
/// (expo-secure-store equivalent.)
class SecureStore implements KeyValueStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
