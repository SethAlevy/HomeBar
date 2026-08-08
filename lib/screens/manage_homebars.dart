import 'package:flutter/material.dart';

import '../services/settings_service.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_template_dialog.dart';
import 'template_content_screen.dart';

// ============================================================================
// ManageHomebarsScreen
// ----------------------------------------------------------------------------
// This screen is the "management panel" for template files: YAML files
// that describe an ingredient list or a recipe list. From here the user
// can:
//   1) pick which templates are the "active" ones for this homebar,
//   2) browse/inspect (and edit) the content of any template, and
//   3) create a brand-new ingredient template from scratch.
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
  // Persisted via SettingsService (see _loadSelection/_selectTemplate below)
  // so the choice survives closing and reopening the app. The ingredient
  // one drives what CategoryBrowserScreen actually loads (see
  // TemplateService.resolveActiveIngredientTemplate) - see the note on
  // _selectTemplate() below for the recipe one, which is still just a
  // label for now.
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
    _loadSelection();
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

  // Restores whichever templates were selected the last time this screen
  // was used, so "Wczytaj szablon" doesn't silently forget the choice
  // every time the app restarts. Runs independently of _loadTemplates()
  // above - the selection is just remembered file paths, so it doesn't
  // need the bundled template list to be loaded first.
  Future<void> _loadSelection() async {
    final settings = await SettingsService.load();

    if (!mounted) return;

    setState(() {
      _selectedIngredientTemplate = settings.selectedIngredientTemplatePath;
      _selectedRecipeTemplate = settings.selectedRecipeTemplatePath;
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
  // NOTE for learners: the ingredient pick here is what
  // TemplateService.resolveActiveIngredientTemplate() reads back (via
  // SettingsService) to decide what CategoryBrowserScreen shows - so
  // confirming a new ingredient template here really does switch the
  // app's active inventory. The recipe pick is still just a label for now:
  // there's no recipe-browsing screen yet to hand it off to.
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

      // Persist the choice so it's still selected next time this screen -
      // or the home screen's summary - is opened, even after the app is
      // fully closed and reopened.
      await SettingsService.saveSelectedTemplates(
        ingredientTemplatePath: tempIngredient,
        recipeTemplatePath: tempRecipe,
      );
    }
  }

  // Opens the "new template" dialog (name + a flat list of category
  // names - nothing more), then actually creates the file, makes it the
  // active ingredient template, and re-scans so it shows up in every
  // template picker from now on.
  Future<void> _addNewIngredientTemplate() async {
    final result = await showDialog<CreateTemplateResult>(
      context: context,
      builder: (context) => const CreateTemplateDialog(),
    );

    if (result == null || !mounted) return;

    final template = await TemplateService.createIngredientTemplate(
      name: result.name,
      categoryNames: result.categoryNames,
    );

    if (!mounted) return;

    // Re-scan so the freshly created file appears in _templates (and
    // therefore in "Wczytaj szablon"/"Edytuj szablony"), not just as the
    // current selection below.
    await _loadTemplates();
    if (!mounted) return;

    setState(() => _selectedIngredientTemplate = template.path);

    await SettingsService.saveSelectedTemplates(
      ingredientTemplatePath: template.path,
      recipeTemplatePath: _selectedRecipeTemplate,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Utworzono nowy zestaw "${template.name}".')),
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
              ],
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
