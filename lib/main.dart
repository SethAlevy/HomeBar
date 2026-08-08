import 'package:flutter/material.dart';
import 'route_observer.dart';
import 'services/auth.dart';
import 'screens/home.dart';

// Entry point of every Dart app - the runtime looks specifically for a
// top-level function named `main`.
//
// We mark it as async because we need to do startup work (Auth.init)
// before rendering the first screen.
void main() async {
  // Ensures Flutter's engine/plugin bindings are fully initialized before
  // any plugin calls happen. Required here because Auth.init() below talks
  // to a native plugin (secure storage) before runApp() has had a chance
  // to do that initialization for us implicitly.
  WidgetsFlutterBinding.ensureInitialized();

  // Prepare authentication data (e.g., create default password once) -
  // see lib/services/auth.dart for details.
  await Auth.init();

  // Build and display the root widget tree. Everything the user sees is a
  // descendant of the widget passed here.
  runApp(const HomeBarApp());
}

// ============================================================================
// HomeBarApp
// ----------------------------------------------------------------------------
// The root widget for the entire application. A MaterialApp sets up the
// app-wide scaffolding Flutter expects: theming, the initial screen, and
// navigation. Everything below `home:` is what actually changes as the
// user navigates around (via Navigator.push/pop calls elsewhere).
// ============================================================================
class HomeBarApp extends StatelessWidget {
  const HomeBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App title used by the OS task switcher in some environments.
      title: 'HomeBar',

      // Colors/typography used when the device is in light mode.
      // ColorScheme.fromSeed() generates a whole matching palette
      // (primary, secondary, surface, etc.) from a single seed color,
      // rather than us having to pick every shade by hand.
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

      // A second, separate ThemeData used automatically when the device
      // is in dark mode (see `themeMode` below).
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

      // ThemeMode.system means Flutter automatically switches between
      // `theme` and `darkTheme` above based on the device's OS-level
      // light/dark setting - we don't have to detect or react to it
      // ourselves.
      themeMode: ThemeMode.system,

      // Lets any screen that mixes in RouteAware (see route_observer.dart)
      // find out when it becomes visible again after a route pushed on
      // top of it gets popped - used by HomeScreen to refresh its
      // selected-templates summary after returning from
      // ManageHomebarsScreen.
      navigatorObservers: [appRouteObserver],

      // First screen shown after startup - the root of the navigation
      // stack that every Navigator.push() call in the app builds on top
      // of.
      home: const HomeScreen(),

      // Hide the red-and-black "DEBUG" ribbon Flutter normally draws in
      // the top-right corner during development builds.
      debugShowCheckedModeBanner: false,
    );
  }
}
