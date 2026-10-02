import 'package:shared_preferences/shared_preferences.dart';

/// Where the [AppStore] keeps its snapshot between launches.
///
/// The store hands over one encoded document and asks for it back; storage
/// knows nothing about tasks or projects. That keeps the format in one place
/// (the store) and lets tests swap in [MemoryAppStorage].
abstract interface class AppStorage {
  /// The last snapshot written, or null on first launch.
  Future<String?> read();

  Future<void> write(String snapshot);
}

/// Device-local storage backed by `shared_preferences` (DataStore on Android).
class SharedPreferencesAppStorage implements AppStorage {
  SharedPreferencesAppStorage({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const _key = 'monday.state';

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> read() => _prefs.getString(_key);

  @override
  Future<void> write(String snapshot) => _prefs.setString(_key, snapshot);
}

/// Keeps the snapshot in memory. Used by tests to simulate a restart: hand the
/// same instance to a fresh store.
class MemoryAppStorage implements AppStorage {
  MemoryAppStorage([this.snapshot]);

  String? snapshot;
  int writes = 0;

  @override
  Future<String?> read() async => snapshot;

  @override
  Future<void> write(String snapshot) async {
    this.snapshot = snapshot;
    writes++;
  }
}
