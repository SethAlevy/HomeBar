import 'package:flutter/material.dart';
import 'category_browser_screen.dart';

// Main landing screen: welcomes the user.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HomeBar',
          style: TextStyle(fontWeight: FontWeight.bold,),
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
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

              _DrawerMenuItem(
                icon: Icons.home_outlined,
                label: 'Strona główna',
                onTap: () => Navigator.pop(context),
              ),
              _DrawerMenuItem(
                icon: Icons.liquor_outlined,
                label: 'Wszystkie składniki',
                onTap: () {
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
              _DrawerMenuItem(
                icon: Icons.settings_outlined,
                label: 'Ustawienia',
                onTap: () => _showComingSoon(context, 'Ustawienia'),
              ),
              const Divider(),
              _DrawerMenuItem(
                icon: Icons.settings_outlined,
                label: 'Ustawienia',
                onTap: () => _showComingSoon(context, 'Ustawienia'),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
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

              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
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
