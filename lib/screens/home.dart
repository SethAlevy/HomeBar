import 'package:flutter/material.dart';
import 'category_browser_screen.dart';
import 'recipe_picker_screen.dart';
import 'recipes_screen.dart';
import '../route_observer.dart';
import '../services/settings_service.dart';
import '../widgets/app_drawer.dart';

// ============================================================================
// HomeScreen
// ----------------------------------------------------------------------------
// The very first screen the user sees: a welcome message, a fixed grid of
// menu buttons, and - at the bottom - a small summary of which ingredient
// and recipe templates are currently selected (see ManageHomebarsScreen).
//
// It's a StatefulWidget (rather than a StatelessWidget) for two reasons:
// it loads that selection from SettingsService once when it first appears,
// and - via the RouteAware mixin - it reloads it again every time the user
// comes back to this screen after visiting "Zarządzaj zestawami", so the
// summary can't go stale if the selection changed there.
// ============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  // Raw file paths, as persisted by SettingsService - null means "nothing
  // selected yet". Turned into short display names via _templateName()
  // down in build().
  String? _selectedIngredientTemplatePath;
  String? _selectedRecipeTemplatePath;

  @override
  void initState() {
    super.initState();
    _loadSelectedTemplates();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribing here (rather than initState) is required because it
    // needs this screen's enclosing ModalRoute, which isn't available yet
    // when initState() runs.
    appRouteObserver.subscribe(this, ModalRoute.of(context)! as PageRoute<void>);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  // RouteAware callback: fires when a route pushed on top of this screen
  // (e.g. ManageHomebarsScreen) is popped and this screen becomes visible
  // again - exactly when the selected templates might have changed.
  @override
  void didPopNext() {
    _loadSelectedTemplates();
  }

  Future<void> _loadSelectedTemplates() async {
    final settings = await SettingsService.load();

    if (!mounted) return;

    setState(() {
      _selectedIngredientTemplatePath = settings.selectedIngredientTemplatePath;
      _selectedRecipeTemplatePath = settings.selectedRecipeTemplatePath;
    });
  }

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

  void _openRecipes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipesScreen(),
      ),
    );
  }

  void _openRecipePicker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecipePickerScreen(),
      ),
    );
  }

  // Turns a full file path into just the trailing filename for display,
  // and normalizes Windows-style backslashes to forward slashes first so
  // the split works the same on every platform. Mirrors the identical
  // helper in ManageHomebarsScreen, so both screens describe "no template
  // selected" the same way.
  String _templateName(String? path) {
    if (path == null) return 'Nie wybrano';
    return path.replaceAll('\\', '/').split('/').last;
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
                      onPressed: () => _openRecipes(context),
                    ),
                    _MenuButton(
                      icon: Icons.liquor_outlined,
                      label: 'Wszystkie składniki',
                      onPressed: () => _openCategoryBrowser(context),
                    ),
                    _MenuButton(
                      icon: Icons.help_outline,
                      label: 'Pomóż mi wybrać',
                      onPressed: () => _openRecipePicker(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // --- Selected templates summary ------------------------
              // A quick "what's active right now" overview, so the user
              // doesn't have to open "Zarządzaj zestawami" just to check.
              _SelectedTemplatesSummary(
                ingredientTemplateName: _templateName(_selectedIngredientTemplatePath),
                recipeTemplateName: _templateName(_selectedRecipeTemplatePath),
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

// A small, unobtrusive line at the bottom of the home screen showing which
// templates are currently selected. Wrap (rather than Row) lets the two
// entries drop onto a second line instead of overflowing if either
// template's filename is long and the screen is narrow.
class _SelectedTemplatesSummary extends StatelessWidget {
  final String ingredientTemplateName;
  final String recipeTemplateName;

  const _SelectedTemplatesSummary({
    required this.ingredientTemplateName,
    required this.recipeTemplateName,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        _SummaryEntry(icon: Icons.liquor_outlined, label: ingredientTemplateName, color: color, style: style),
        _SummaryEntry(icon: Icons.menu_book_outlined, label: recipeTemplateName, color: color, style: style),
      ],
    );
  }
}

// One "icon + template name" entry within _SelectedTemplatesSummary.
class _SummaryEntry extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final TextStyle? style;

  const _SummaryEntry({
    required this.icon,
    required this.label,
    required this.color,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}
