import 'package:flutter/material.dart';
import 'services/auth.dart';
import 'screens/home.dart';

// Entry point of every Dart app.
//
// We mark it as async because we need to do startup work (Auth.init)
// before rendering the first screen.
void main() async {
  // Ensures Flutter engine is fully initialized before plugin calls.
  // Required for using secure storage during app startup.
  WidgetsFlutterBinding.ensureInitialized();

  // Prepare authentication data (e.g., create default password once).
  await Auth.init();

  // Build and display the root widget tree.
  runApp(const HomeBarApp());
}

// Root widget for the entire application.
class HomeBarApp extends StatelessWidget {
  const HomeBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title used by the OS task switcher in some environments.
      title: 'HomeBar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepOrange,
          foregroundColor: Color.fromARGB(255, 244, 158, 52),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromARGB(255, 163, 47, 12),
          foregroundColor: Color.fromARGB(255, 220, 169, 1),
        ),
      ),
      // First screen shown after startup.
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      // Hide debug ribbon in the top-right corner.
      debugShowCheckedModeBanner: false,
    );
  }
}
