import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ============================================================================
// Auth
// ----------------------------------------------------------------------------
// A very small "service" class - a place for logic that isn't tied to any
// one screen. This one gate-keeps edit operations (like saving an
// ingredient) behind a single shared password.
//
// It stores that password using flutter_secure_storage, a plugin that
// keeps data in the platform's encrypted storage (Android Keystore /
// iOS Keychain / etc.) rather than a plain file, so it's safer than
// writing the password into a normal settings file.
//
// Every member here is `static`, meaning you call them directly on the
// class (Auth.init(), Auth.checkPassword(...)) rather than creating an
// `Auth()` instance first - appropriate since there's only ever one shared
// password for the whole app.
// ============================================================================
class Auth {
  // The key under which the password value is stored - secure storage
  // works like a key/value dictionary, similar to SharedPreferences.
  static const String _passwordKey = 'edit_password';

  // Password written the very first time the app runs, before the user has
  // ever set their own. NOTE: shipping a hardcoded default like this is
  // fine for a learning/demo project, but a real production app should
  // force the user to set their own password on first run instead.
  static const String _defaultPassword = 'admin123'; // Change this in production!

  // The secure storage plugin instance used for all reads/writes below.
  static const _storage = FlutterSecureStorage();

  // Called once during app startup (see main.dart). If no password has
  // ever been saved, write the default one so checkPassword() always has
  // something to compare against.
  static Future<void> init() async {
    final storedPassword = await _storage.read(key: _passwordKey);
    if (storedPassword == null) {
      await _storage.write(key: _passwordKey, value: _defaultPassword);
    }
  }

  // Compares user-entered text against the saved password.
  // Returns true only on an exact match.
  static Future<bool> checkPassword(String input) async {
    final storedPassword = await _storage.read(key: _passwordKey);
    return input == storedPassword;
  }
}
