import 'package:flutter/material.dart';
import 'category_browser_screen.dart';
import '../widgets/app_drawer.dart';

// ============================================================================
// HomeScreen
// ----------------------------------------------------------------------------
// The very first screen the user sees. It's a StatelessWidget because it
// has no data of its own that changes over time - it just displays a
// welcome message and a fixed grid of menu buttons.
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Shared handler for menu buttons whose destination screen doesn't exist
  // yet - shows a small toast-like message instead of doing nothing.
  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label — coming soon!')),
    );
  }

  void _openCategoryBrowser(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CategoryBrowserScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the standard "screen skeleton": an app bar, a
    // side drawer, and a body area - we only need to fill in the pieces
    // we want.
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomeBar',
          style: TextStyle(fontWeight: FontWeight.bold,),
        ),
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              // --- Decorative header icon ------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_bar,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 16),

              // --- Welcome text -----------------------------------------
              Text(
                'Witaj w naszym barze!',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
              ),

              const SizedBox(height: 8),

              Text(
                'Sprawdź nasze składniki lub wybierz przepis!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),

              const SizedBox(height: 32),

              // --- Main menu grid -----------------------------------------
              // Expanded lets the grid fill whatever vertical space is left
              // in the Column, so it doesn't just take its minimum size.
              Expanded(
                child: GridView.count(
                  // 2 buttons per row.
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Width-to-height ratio of each grid cell; >1 means wider
                  // than tall.
                  childAspectRatio: 1.35,
                  children: [
                    _MenuButton(
                      icon: Icons.home_outlined,
                      label: 'Domowe wytwory',
                      onPressed: () => _showComingSoon(context, 'Domowe wytwory'),
                    ),
                    _MenuButton(
                      icon: Icons.menu_book_outlined,
                      label: 'Przepisy koktajlowe',
                      onPressed: () => _showComingSoon(context, 'Przepisy koktajlowe'),
                    ),
                    _MenuButton(
                      icon: Icons.liquor_outlined,
                      label: 'Wszystkie składniki',
                      // The only button that's actually wired up to a real
                      // screen today - the rest are placeholders.
                      onPressed: () => _openCategoryBrowser(context),
                    ),
                    _MenuButton(
                      icon: Icons.help_outline,
                      label: 'Pomóż mi wybrać',
                      onPressed: () => _showComingSoon(context, 'Pomóż mi wybrać'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// One big, icon-over-label button in the home grid. Its own widget so the
// GridView above can just list four of these instead of repeating the
// full FilledButton.tonal(...) styling four times.
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
