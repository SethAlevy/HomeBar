import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Small helper service for edit authorization.
//
// It stores a single password in secure device storage.
class Auth {
  // Key used to store/retrieve password value.
  static const String _passwordKey = 'edit_password';

  // Initial password used only if nothing has been stored yet.
  static const String _defaultPassword = 'admin123'; // Change this in production!

  // Plugin API for encrypted key/value storage on device.
  static const _storage = FlutterSecureStorage();

  // Runs once during app startup.
  // If no password exists, write a default one.
  static Future<void> init() async {
    final storedPassword = await _storage.read(key: _passwordKey);
    if (storedPassword == null) {
      await _storage.write(key: _passwordKey, value: _defaultPassword);
    }
  }

  // Compares user input with the saved password.
  static Future<bool> checkPassword(String input) async {
    final storedPassword = await _storage.read(key: _passwordKey);
    return input == storedPassword;
  }

}
