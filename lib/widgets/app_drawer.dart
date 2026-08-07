import 'package:flutter/material.dart';

import '../screens/category_browser_screen.dart';
import '../screens/manage_homebars.dart';

// ============================================================================
// AppDrawer
// ----------------------------------------------------------------------------
// The slide-out side menu (a Material "Drawer") shared by every screen that
// includes `drawer: const AppDrawer()` in its Scaffold. Centralizing the
// menu here means adding a new destination only requires editing this one
// file, and every screen automatically gets the update.
// ============================================================================
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // Shared handler for menu items whose destination screen doesn't exist
  // yet - shows a small toast-like message instead of navigating nowhere
  // silently.
  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon!')),
    );
  }

  // Pops every screen off the navigation stack except the very first one,
  // effectively returning to HomeScreen from anywhere in the app.
  void _goHome(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _openCategoryBrowser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryBrowserScreen(),
      ),
    );
  }

  void _openManageHomebars(BuildContext context) {
    // Close the drawer first, then push the new screen - otherwise the
    // drawer would still be open (just hidden behind the new screen) when
    // the user eventually navigates back.
    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageHomebarsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        // SafeArea keeps content clear of notches/status bars/system UI,
        // so the drawer header isn't drawn underneath a phone's camera
        // cutout, for example.
        child: Column(
          children: [
            // --- Header: app icon + name -------------------------------
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_bar,
                    size: 40,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'HomeBar',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),

            // --- Primary navigation destinations ------------------------
            _DrawerMenuItem(
              icon: Icons.home_outlined,
              label: 'Strona główna',
              onTap: () => _goHome(context),
            ),
            _DrawerMenuItem(
              icon: Icons.liquor_outlined,
              label: 'Wszystkie składniki',
              onTap: () {
                // Close the drawer, then navigate - same reasoning as
                // _openManageHomebars() above.
                Navigator.pop(context);
                _openCategoryBrowser(context);
              },
            ),
            _DrawerMenuItem(
              icon: Icons.checklist_outlined,
              label: 'Domowe produkty',
              onTap: () => _showComingSoon(context, 'Domowe produkty'),
            ),
            _DrawerMenuItem(
              icon: Icons.menu_book_outlined,
              label: 'Przepisy',
              onTap: () => _showComingSoon(context, 'Przepisy'),
            ),

            // Divider visually separates "browse content" items above
            // from "app management" items below.
            const Divider(),
            _DrawerMenuItem(
              icon: Icons.settings_outlined,
              label: 'Zarządzaj zestawami',
              onTap: () => _openManageHomebars(context),
            ),
            _DrawerMenuItem(
              icon: Icons.settings_outlined,
              label: 'Ustawienia',
              onTap: () => _showComingSoon(context, 'Ustawienia'),
            ),
          ],
        ),
      ),
    );
  }
}

// One row in the drawer's menu - just an icon, a label, and a tap handler.
// Kept as its own tiny widget so the Column above stays readable instead of
// repeating a full ListTile(...) definition for every single item.
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}
