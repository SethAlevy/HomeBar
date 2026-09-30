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
// that describe an ingredient list or a recipe list. It shows just two
// tiles - "Składniki" and "Przepisy" - each naming the currently active
// template of that kind. Tapping either opens a modal sheet (see
// _TemplateListSheet) listing every template of that type: tapping a row
// makes it the active one (replacing the old separate "Wczytaj szablon"
// flow), its "Edytuj" button opens the full tree editor
// (TemplateContentScreen), and a persistent "Dodaj nowy" bar at the bottom
// of the sheet creates a brand-new template of that type.
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
  // Persisted via SettingsService (see _loadSelection/_selectActiveTemplate
  // below) so the choice survives closing and reopening the app. The
  // ingredient one drives what CategoryBrowserScreen actually loads (see
  // TemplateService.resolveActiveIngredientTemplate); the recipe one drives
  // RecipesScreen the same way (see TemplateService.resolveActiveRecipeTemplate).
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
  // was used, so the active-template choice doesn't silently reset every
  // time the app restarts. Runs independently of _loadTemplates() above -
  // the selection is just remembered file paths, so it doesn't need the
  // bundled template list to be loaded first.
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
  List<TemplateFile> get _ingredientTemplates =>
      _templates.where((t) => t.type == TemplateType.ingredient).toList();

  List<TemplateFile> get _recipeTemplates =>
      _templates.where((t) => t.type == TemplateType.recipe).toList();

  String _activeNameFor(List<TemplateFile> templates, String? selectedPath) {
    if (selectedPath == null) return 'Nie wybrano';
    return templates
        .firstWhere(
          (t) => t.path == selectedPath,
          orElse: () => TemplateFile(path: selectedPath, name: selectedPath, type: TemplateType.ingredient),
        )
        .name;
  }

  // Marks `template` as the active one of its type and persists the choice
  // immediately - there's no separate "Zastosuj" confirmation step anymore,
  // tapping a row in the modal sheet takes effect right away.
  Future<void> _selectActiveTemplate(TemplateType type, TemplateFile template) async {
    setState(() {
      if (type == TemplateType.ingredient) {
        _selectedIngredientTemplate = template.path;
      } else {
        _selectedRecipeTemplate = template.path;
      }
    });

    await SettingsService.saveSelectedTemplates(
      ingredientTemplatePath: _selectedIngredientTemplate,
      recipeTemplatePath: _selectedRecipeTemplate,
    );
  }

  // Dismisses the modal sheet and pushes the full tree editor for one
  // template - shared by both tiles' sheets via their "Edytuj" buttons.
  void _openEditor(TemplateFile template) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TemplateContentScreen(template: template)),
    );
  }

  // The modal sheet's "Dodaj nowy": opens the right creation dialog for
  // `type`, creates the template, makes it the active one, and hands the
  // new TemplateFile back so the sheet can show it immediately.
  Future<TemplateFile?> _createNewTemplate(TemplateType type) async {
    if (type == TemplateType.ingredient) {
      final result = await showDialog<CreateTemplateResult>(
        context: context,
        builder: (context) => const CreateTemplateDialog(),
      );
      if (result == null || !mounted) return null;

      final template = await TemplateService.createIngredientTemplate(
        name: result.name,
        categoryNames: result.categoryNames,
      );
      if (!mounted) return null;
      await _selectActiveTemplate(TemplateType.ingredient, template);
      return template;
    }

    final name = await _promptTemplateName(context);
    if (name == null || !mounted) return null;

    final template = await TemplateService.createRecipeTemplate(name: name);
    if (!mounted) return null;
    await _selectActiveTemplate(TemplateType.recipe, template);
    return template;
  }

  // Opens the modal sheet for one template type (see _TemplateListSheet).
  // Re-scans the full template list once the sheet closes, in case a new
  // template was created while it was open.
  Future<void> _openTemplatesModal(TemplateType type) async {
    final templates = type == TemplateType.ingredient ? _ingredientTemplates : _recipeTemplates;
    final selectedPath =
        type == TemplateType.ingredient ? _selectedIngredientTemplate : _selectedRecipeTemplate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TemplateListSheet(
        type: type,
        templates: templates,
        selectedPath: selectedPath,
        onSelect: (template) => _selectActiveTemplate(type, template),
        onEdit: _openEditor,
        onAddNew: () => _createNewTemplate(type),
      ),
    );

    await _loadTemplates();
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
                _ManageTile(
                  icon: Icons.liquor_outlined,
                  title: 'Składniki',
                  subtitle: 'Aktywny: ${_activeNameFor(_ingredientTemplates, _selectedIngredientTemplate)}',
                  onTap: () => _openTemplatesModal(TemplateType.ingredient),
                ),
                const SizedBox(height: 12),
                _ManageTile(
                  icon: Icons.local_bar_outlined,
                  title: 'Przepisy',
                  subtitle: 'Aktywny: ${_activeNameFor(_recipeTemplates, _selectedRecipeTemplate)}',
                  onTap: () => _openTemplatesModal(TemplateType.recipe),
                ),
              ],
            ),
    );
  }
}

// One of the two top-level tiles ("Składniki"/"Przepisy"): an icon, a
// title, and a subtitle naming the currently active template of that kind.
// Tapping it opens that type's _TemplateListSheet.
class _ManageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ManageTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// _TemplateListSheet
// ----------------------------------------------------------------------------
// The modal opened by tapping a _ManageTile: every template of one type,
// each row showing whether it's the active one, tappable to make it active,
// with its own "Edytuj" button to open the full tree editor. A persistent
// "Dodaj nowy" bar sits pinned at the bottom of the sheet regardless of how
// far the list is scrolled.
//
// Keeps a local copy of `templates`/`selectedPath` so tapping a row or
// adding a new template updates the sheet immediately, without waiting for
// it to close and the parent screen to rebuild.
// ============================================================================
class _TemplateListSheet extends StatefulWidget {
  final TemplateType type;
  final List<TemplateFile> templates;
  final String? selectedPath;
  final Future<void> Function(TemplateFile template) onSelect;
  final void Function(TemplateFile template) onEdit;
  final Future<TemplateFile?> Function() onAddNew;

  const _TemplateListSheet({
    required this.type,
    required this.templates,
    required this.selectedPath,
    required this.onSelect,
    required this.onEdit,
    required this.onAddNew,
  });

  @override
  State<_TemplateListSheet> createState() => _TemplateListSheetState();
}

class _TemplateListSheetState extends State<_TemplateListSheet> {
  late List<TemplateFile> _templates;
  String? _selectedPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _templates = widget.templates;
    _selectedPath = widget.selectedPath;
  }

  Future<void> _select(TemplateFile template) async {
    if (_selectedPath == template.path) return;
    setState(() => _selectedPath = template.path);
    await widget.onSelect(template);
  }

  Future<void> _addNew() async {
    setState(() => _busy = true);
    final created = await widget.onAddNew();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (created != null) {
        _templates = [..._templates, created];
        _selectedPath = created.path;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == TemplateType.ingredient ? 'Szablony składników' : 'Szablony przepisów';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Zamknij',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _templates.isEmpty
                ? const Center(child: Text('Brak szablonów.'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final template = _templates[index];
                      final isActive = template.path == _selectedPath;
                      return ListTile(
                        leading: Icon(
                          isActive ? Icons.check_circle : Icons.description_outlined,
                          color: isActive ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(template.name),
                        subtitle: Text(isActive ? 'Aktywny' : template.path),
                        selected: isActive,
                        onTap: () => _select(template),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          tooltip: 'Edytuj',
                          onPressed: () => widget.onEdit(template),
                        ),
                      );
                    },
                  ),
          ),
          // The persistent "Dodaj nowy" footer - stays pinned at the
          // bottom of the sheet regardless of how far the list above is
          // scrolled.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _addNew,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Dodaj nowy'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Minimal single-field prompt for naming a brand-new recipe template - no
// categories concept applies to recipes, so unlike CreateTemplateDialog
// (ingredients) this needs nothing but a name.
Future<String?> _promptTemplateName(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nowy szablon przepisów'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nazwa szablonu'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anuluj'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Utwórz'),
        ),
      ],
    ),
  );
  controller.dispose();

  if (result == null || result.isEmpty) return null;
  return result;
}
