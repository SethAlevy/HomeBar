import 'package:flutter/material.dart';

// Shared RouteObserver instance, registered on MaterialApp in main.dart
// (via navigatorObservers). A screen that needs to know "I've become
// visible again after a route pushed on top of me was popped" - e.g. to
// refresh data that might have changed on that other screen, the way
// HomeScreen refreshes its selected-templates summary after returning
// from ManageHomebarsScreen - can mix in RouteAware, subscribe to this in
// didChangeDependencies(), and override didPopNext().
final RouteObserver<PageRoute<void>> appRouteObserver = RouteObserver<PageRoute<void>>();
