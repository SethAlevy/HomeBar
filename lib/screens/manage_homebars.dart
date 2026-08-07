import 'package:flutter/material.dart';

import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import 'template_content_screen.dart';

// ============================================================================
// ManageHomebarsScreen
// ----------------------------------------------------------------------------
// This screen is the "management panel" for template files: the bundled
// YAML files that describe an ingredient list or a recipe list. From here
// the user can:
//   1) pick which templates are the "active" ones for this homebar,
//   2) browse/inspect the content of any template, and
//   3) create a new (currently placeholder) ingredient template.
//
// It is a StatefulWidget because it needs to remember things across
// rebuilds: the list of templates loaded from disk/assets, whether we are
// still loading, and which template is currently selected as "active".
// ============================================================================
class ManageHomebarsScreen extends StatefulWidget {
  const ManageHomebarsScreen({super.key});

  @override
  State<ManageHomebarsScreen> createState() => _ManageHomebarsScreenState();
}

// The "State" object holds the mutable data for ManageHomebarsScreen.
// Flutter splits a StatefulWidget into two classes: the widget itself
// (immutable, describes configuration) and its State (mutable, holds data
// that can change over time and trigger a re-render via setState()).
class _ManageHomebarsScreenState extends State<ManageHomebarsScreen> {
  // All templates discovered by TemplateService (both ingredient & recipe).
  List<TemplateFile> _templates = [];

  // Path of the template currently marked as "active" for ingredients/recipes.
  // These are just labels shown on screen for now - see the note on
  // _selectTemplate() below about what "applying" a template does today.
  String? _selectedIngredientTemplate;
  String? _selectedRecipeTemplate;

  // Drives the loading spinner while templates are being read from disk.
  bool _isLoading = true;

  @override
  void initState() {
    // initState() runs exactly once, right when this screen is first
    // created - a good place to kick off one-time setup like loading data.
    super.initState();
    _loadTemplates();
  }

  // Asks TemplateService to scan for bundled templates, then stores the
  // result in state so the UI can rebuild with the loaded data.
  Future<void> _loadTemplates() async {
    final templates = await TemplateService.loadBundledTemplates();

    // `mounted` is false if the widget was removed from the tree while we
    // were awaiting (e.g. user navigated away). Calling setState() on an
    // unmounted widget throws, so we guard against it.
    if (!mounted) return;

    setState(() {
      _templates = templates;
      _isLoading = false;
    });
  }

  // Convenience getters that filter the full template list down to just
  // ingredients or just recipes. They recompute on every access rather than
  // being cached - fine here since `_templates` is small and these are only
  // read while building the UI.
  List<TemplateFile> get _ingredientTemplates => _templates
      .where((t) => t.type == TemplateType.ingredient)
      .toList();

  List<TemplateFile> get _recipeTemplates => _templates
      .where((t) => t.type == TemplateType.recipe)
      .toList();

  // Opens the "Wczytaj szablon" (Load template) dialog, where the user picks
  // one ingredient template and one recipe template to mark as active.
  //
  // NOTE for learners: this only updates local screen state for display
  // purposes right now - it does not yet make the app actually load data
  // from the chosen files (that would live in a service like FileHandler).
  Future<void> _selectTemplate() async {
    // These are *temporary* picks made inside the dialog. We don't touch the
    // real _selectedIngredientTemplate/_selectedRecipeTemplate fields until
    // the user confirms with "Zastosuj" (Apply) - that way "Anuluj" (Cancel)
    // can simply discard them.
    String? tempIngredient = _selectedIngredientTemplate;
    String? tempRecipe = _selectedRecipeTemplate;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        // StatefulBuilder gives a dialog its own tiny bit of local state
        // (dialogSetState) without needing a whole separate StatefulWidget
        // class. We need it here because tapping a template inside the
        // dialog should visually update the dialog immediately.
        builder: (context, dialogSetState) {
          return AlertDialog(
            title: const Text('Wczytaj szablon'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TemplateOptionList(
                  title: 'Wybierz listę składników',
                  selectedPath: tempIngredient,
                  options: _ingredientTemplates,
                  onSelected: (template) {
                    tempIngredient = template.path;
                    // Rebuild just the dialog so the new selection shows up.
                    dialogSetState(() {});
                  },
                ),
                const SizedBox(height: 12),
                _TemplateOptionList(
                  title: 'Wybierz listę przepisów',
                  selectedPath: tempRecipe,
                  options: _recipeTemplates,
                  onSelected: (template) {
                    tempRecipe = template.path;
                    dialogSetState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                // Passing `false` tells the caller "user cancelled".
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                // Passing `true` tells the caller "user confirmed".
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Zastosuj'),
              ),
            ],
          );
        },
      ),
    );

    // Only commit the temporary picks to real state if the dialog was
    // confirmed (result == true) and this screen is still on screen.
    if (result == true && mounted) {
      setState(() {
        _selectedIngredientTemplate = tempIngredient;
        _selectedRecipeTemplate = tempRecipe;
      });
    }
  }

  // Placeholder flow for creating a brand-new ingredient template.
  // Today TemplateService.createIngredientTemplate() just hands back the
  // existing default template info rather than creating a new file - it's a
  // stand-in until real "new template" creation is implemented.
  Future<void> _addNewIngredientTemplate() async {
    final template = await TemplateService.createIngredientTemplate();

    if (!mounted) return;

    setState(() {
      _selectedIngredientTemplate = template.path;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Utworzono nowy szablon składników.')),
    );
  }

  // Opens the "Edytuj szablony" (Edit templates) flow: first a small dialog
  // to pick *which* template to inspect, then - once chosen - pushes a new
  // full screen that shows that template's entire tree of categories and
  // ingredients.
  Future<void> _editTemplates() async {
    // showDialog<TemplateFile> means: this dialog, when popped, hands back
    // either a TemplateFile (the one the user tapped) or null (dismissed).
    final selected = await showDialog<TemplateFile>(
      context: context,
      builder: (context) => _TemplateSelectorDialog(
        templates: _templates,
      ),
    );

    if (selected == null || !mounted) return;

    // Navigator.push adds a new screen on top of the navigation stack;
    // MaterialPageRoute gives it the standard Material slide-in transition.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TemplateContentScreen(template: selected),
      ),
    );
  }

  // Turns a full file path into just the trailing filename for display,
  // and normalizes Windows-style backslashes to forward slashes first so
  // the split works the same on every platform.
  String _templateName(String? path) {
    if (path == null) return 'Nie wybrano';
    return path.replaceAll('\\', '/').split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    // build() runs every time Flutter needs to redraw this screen (e.g.
    // after setState()). It should be a pure function of the current state
    // - describing *what* the UI should look like, not performing work.
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Zarządzaj zestawami',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      drawer: const AppDrawer(),
      body: _isLoading
          // While templates are loading, show a spinner instead of an
          // empty/broken-looking screen.
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- Action buttons -------------------------------------
                FilledButton.icon(
                  onPressed: _selectTemplate,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Wczytaj szablon'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _editTemplates,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edytuj szablony'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addNewIngredientTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj nowy zestaw'),
                ),
                const SizedBox(height: 32),

                // --- Summary of what's currently active -----------------
                _SelectedTemplateCard(
                  icon: Icons.liquor_outlined,
                  title: 'Wybrany szablon składników',
                  templateName: _templateName(_selectedIngredientTemplate),
                ),
                const SizedBox(height: 12),
                _SelectedTemplateCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Wybrany szablon przepisów',
                  templateName: _templateName(_selectedRecipeTemplate),
                ),
              ],
            ),
    );
  }
}

// Small, reusable card that just shows an icon + a title + the currently
// selected template's name. Pulling this into its own widget avoids
// repeating the same Card/ListTile structure twice in build() above.
class _SelectedTemplateCard extends StatelessWidget {
  const _SelectedTemplateCard({
    required this.icon,
    required this.title,
    required this.templateName,
  });

  final IconData icon;
  final String title;
  final String templateName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(templateName),
      ),
    );
  }
}

// Shared building block for "here is a titled, expandable list of template
// files, tap one to select it" - used both by the "Wczytaj szablon" dialog
// (where selecting just updates local state) and by the "Edytuj szablony"
// dialog (where selecting immediately closes the dialog). The two call
// sites decide what "selecting" means via the onSelected callback; this
// widget only handles displaying the options.
class _TemplateOptionList extends StatelessWidget {
  final String title;
  final List<TemplateFile> options;
  final ValueChanged<TemplateFile> onSelected;

  // The path of the option that should be shown as "currently selected".
  // Pass null when there is no meaningful "current selection" concept
  // (e.g. the pick-once-and-navigate-away flow).
  final String? selectedPath;

  const _TemplateOptionList({
    required this.title,
    required this.options,
    required this.onSelected,
    this.selectedPath,
  });

  @override
  Widget build(BuildContext context) {
    // ExpansionTile is a ready-made "tap to expand/collapse" list tile -
    // it keeps its own open/closed state internally, so we don't need to
    // manage that here.
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(
        selectedPath == null ? 'Wybierz' : _fileNameOf(selectedPath!),
      ),
      children: options.isEmpty
          // Guard against an empty list so users see a helpful message
          // instead of a blank, seemingly-broken expanded section.
          ? const [ListTile(title: Text('Brak szablonów'))]
          : options
              .map(
                (template) => ListTile(
                  selected: selectedPath == template.path,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(template.name),
                  subtitle: Text(template.path),
                  onTap: () => onSelected(template),
                ),
              )
              .toList(),
    );
  }

  // Same "strip path down to filename" logic used elsewhere; kept local to
  // this widget since it is only needed for the subtitle above.
  String _fileNameOf(String path) => path.replaceAll('\\', '/').split('/').last;
}

// Dialog shown by "Edytuj szablony": pick one template (ingredient or
// recipe) to open in the full-screen tree viewer. There is no "Apply"
// step here - tapping an option immediately pops the dialog with that
// template as the result.
class _TemplateSelectorDialog extends StatelessWidget {
  final List<TemplateFile> templates;

  const _TemplateSelectorDialog({
    required this.templates,
  });

  @override
  Widget build(BuildContext context) {
    final ingredientTemplates = templates
        .where((template) => template.type == TemplateType.ingredient)
        .toList();

    final recipeTemplates = templates
        .where((template) => template.type == TemplateType.recipe)
        .toList();

    return AlertDialog(
      title: const Text('Edytuj szablony'),
      content: SizedBox(
        // double.maxFinite lets the dialog grow as wide as its parent
        // allows, instead of shrinking to fit its (variable-width) content.
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TemplateOptionList(
                title: 'Składniki',
                options: ingredientTemplates,
                onSelected: (template) => Navigator.pop(context, template),
              ),
              const SizedBox(height: 8),
              _TemplateOptionList(
                title: 'Przepisy',
                options: recipeTemplates,
                onSelected: (template) => Navigator.pop(context, template),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
      ],
    );
  }
}
