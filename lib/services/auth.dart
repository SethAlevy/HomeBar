import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Auth {
  static const String _passwordKey = 'edit_password';
  static const String _defaultPassword = 'admin123'; // Change this in production!

  static const _storage = FlutterSecureStorage();

  // Initialize password (call this at app start)
  static Future<void> init() async {
    final storedPassword = await _storage.read(key: _passwordKey);
    if (storedPassword == null) {
      await _storage.write(key: _passwordKey, value: _defaultPassword);
    }
  }

  // Check if the provided password is correct
  static Future<bool> checkPassword(String input) async {
    final storedPassword = await _storage.read(key: _passwordKey);
    return input == storedPassword;
  }

  // Update the password
  static Future<void> updatePassword(String newPassword) async {
    await _storage.write(key: _passwordKey, value: newPassword);
  }
}
