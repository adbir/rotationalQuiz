import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key-value persistence, so repositories can be tested without
/// platform channels.
abstract interface class LocalStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

/// [LocalStore] backed by `shared_preferences` (localStorage on the web).
class SharedPreferencesStore implements LocalStore {
  SharedPreferencesStore._(this._prefs);

  static Future<SharedPreferencesStore> create() async =>
      SharedPreferencesStore._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        ),
      );

  final SharedPreferencesWithCache _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// [LocalStore] that forgets everything on restart; used in tests.
class InMemoryStore implements LocalStore {
  InMemoryStore([Map<String, String>? values]) : _values = {...?values};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;

  @override
  Future<void> remove(String key) async => _values.remove(key);
}
