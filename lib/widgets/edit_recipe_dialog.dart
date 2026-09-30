import 'package:flutter/material.dart';

import '../models/recipe.dart';
import 'editable_chip_list.dart';

// One editable ingredient line's three text fields, bundled together so the
// dialog's state can hold a `List` of these instead of three parallel
// lists that would have to stay in sync by index.
class _IngredientLineControllers {
  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController matchKey;

  _IngredientLineControllers({required this.name, required this.amount, required this.matchKey});

  factory _IngredientLineControllers.empty() => _IngredientLineControllers(
        name: TextEditingController(),
        amount: TextEditingController(),
        matchKey: TextEditingController(),
      );

  void dispose() {
    name.dispose();
    amount.dispose();
    matchKey.dispose();
  }
}

// ============================================================================
// EditRecipeDialog
// ----------------------------------------------------------------------------
// Full edit form for one recipe, shown as a modal dialog - the recipe
// counterpart to EditTemplateIngredientDialog. Pass `recipe: null` to
// instead draft a brand-new one from blank fields (used for "Dodaj
// przepis"). Editable name, a dynamic list of ingredient lines
// (name/amount/optional match key - see RecipeIngredient.matchKey), a
// dynamic list of instruction steps (re-joined into the numbered
// "1. ... 2. ..." string Recipe.instructionSteps expects on save), free-form
// comments, and tags (reusing EditableChipList, same as everywhere else
// tags are edited).
//
// Only builds and returns the edited Recipe - the caller
// (TemplateContentScreen) decides whether that means replacing an existing
// entry or appending a new one.
// ============================================================================
class EditRecipeDialog extends StatefulWidget {
  final Recipe? recipe;

  const EditRecipeDialog({this.recipe, super.key});

  @override
  State<EditRecipeDialog> createState() => _EditRecipeDialogState();
}

class _EditRecipeDialogState extends State<EditRecipeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _commentsController;
  late final TextEditingController _newTagController;

  List<_IngredientLineControllers> _ingredientLines = [];
  List<TextEditingController> _stepControllers = [];
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;

    // Rebuilds the dialog as the name is typed, so the "Zapisz" button's
    // enabled/disabled state (see _canSave) stays in sync.
    _nameController = TextEditingController(text: recipe?.name ?? '')
      ..addListener(() => setState(() {}));
    _commentsController = TextEditingController(text: recipe?.comments ?? '');
    _newTagController = TextEditingController();
    _tags = List<String>.from(recipe?.tags ?? []);

    _ingredientLines = (recipe?.ingredients ?? [])
        .map(
          (i) => _IngredientLineControllers(
            name: TextEditingController(text: i.name),
            amount: TextEditingController(text: i.amount),
            // Only show a match key when it actually differs from the
            // name - same "defaulted vs. explicit" distinction the rest
            // of the app draws (see RecipeIngredient.matchKey).
            matchKey: TextEditingController(text: i.matchKey == i.name ? '' : i.matchKey),
          ),
        )
        .toList();
    if (_ingredientLines.isEmpty) _ingredientLines.add(_IngredientLineControllers.empty());

    _stepControllers =
        (recipe?.instructionSteps ?? []).map((s) => TextEditingController(text: s)).toList();
    if (_stepControllers.isEmpty) _stepControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentsController.dispose();
    _newTagController.dispose();
    for (final line in _ingredientLines) {
      line.dispose();
    }
    for (final controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _addIngredientLine() {
    setState(() => _ingredientLines = [..._ingredientLines, _IngredientLineControllers.empty()]);
  }

  void _removeIngredientLine(_IngredientLineControllers line) {
    setState(() => _ingredientLines = _ingredientLines.where((l) => l != line).toList());
    line.dispose();
  }

  void _reorderIngredientLines(int oldIndex, int newIndex) {
    setState(() {
      final line = _ingredientLines.removeAt(oldIndex);
      _ingredientLines.insert(newIndex, line);
    });
  }

  void _addStep() {
    setState(() => _stepControllers = [..._stepControllers, TextEditingController()]);
  }

  void _removeStep(TextEditingController controller) {
    setState(() => _stepControllers = _stepControllers.where((c) => c != controller).toList());
    controller.dispose();
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final controller = _stepControllers.removeAt(oldIndex);
      _stepControllers.insert(newIndex, controller);
    });
  }

  void _addTag() {
    final tag = _newTagController.text.trim();
    if (tag.isEmpty || _tags.contains(tag)) {
      _newTagController.clear();
      return;
    }
    setState(() {
      _tags = [..._tags, tag];
      _newTagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags = _tags.where((t) => t != tag).toList());
  }

  void _save() {
    if (!_canSave) return;

    final ingredients = _ingredientLines
        .where((line) => line.name.text.trim().isNotEmpty)
        .map((line) {
          final matchKey = line.matchKey.text.trim();
          return RecipeIngredient(
            name: line.name.text.trim(),
            amount: line.amount.text.trim(),
            matchKey: matchKey.isEmpty ? null : matchKey,
          );
        })
        .toList();

    final steps = _stepControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final instructions = List.generate(steps.length, (i) => '${i + 1}. ${steps[i]}').join(' ');

    Navigator.pop(
      context,
      Recipe(
        name: _nameController.text.trim(),
        ingredients: ingredients,
        instructions: instructions,
        comments: _commentsController.text.trim(),
        tags: _tags,
      ),
    );
  }

  // One draggable row in the ingredients ReorderableListView: a drag
  // handle, then the name/amount/match key fields, then a remove button.
  // `index` is this row's current position - required by
  // ReorderableDragStartListener so it knows which item is being dragged.
  Widget _buildIngredientRow(_IngredientLineControllers line, int index) {
    return Padding(
      key: ValueKey(line),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 12, right: 4),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: line.name,
              decoration: const InputDecoration(labelText: 'Nazwa', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.amount,
              decoration: const InputDecoration(labelText: 'Ilość', isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.matchKey,
              decoration: const InputDecoration(
                labelText: 'Klucz dopasowania',
                isDense: true,
                hintText: '(opcjonalnie)',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Usuń składnik',
            visualDensity: VisualDensity.compact,
            onPressed: _ingredientLines.length > 1 ? () => _removeIngredientLine(line) : null,
          ),
        ],
      ),
    );
  }

  // One draggable row in the instructions ReorderableListView: a drag
  // handle, the step number, the step's text field, then a remove button.
  Widget _buildStepRow(int index) {
    final controller = _stepControllers[index];
    return Padding(
      key: ValueKey(controller),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.only(top: 12, right: 4),
              child: Icon(Icons.drag_handle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 6),
            child: SizedBox(width: 18, child: Text('${index + 1}.')),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(isDense: true),
              maxLines: null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            tooltip: 'Usuń krok',
            visualDensity: VisualDensity.compact,
            onPressed: _stepControllers.length > 1 ? () => _removeStep(controller) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recipe == null ? 'Nowy przepis' : 'Edytuj przepis'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              const SizedBox(height: 16),

              Text('Składniki', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                'Przeciągnij za uchwyt, aby zmienić kolejność',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              // shrinkWrap + NeverScrollableScrollPhysics: this list sizes
              // itself to its own content and lets the surrounding
              // SingleChildScrollView handle all the actual scrolling,
              // instead of the two competing over drag gestures.
              // buildDefaultDragHandles: false because dragging from
              // anywhere on the row would fight with the TextFields' own
              // text-selection gestures - see the explicit drag handle
              // (ReorderableDragStartListener) in _buildIngredientRow.
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _reorderIngredientLines,
                children: [
                  for (var i = 0; i < _ingredientLines.length; i++)
                    _buildIngredientRow(_ingredientLines[i], i),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addIngredientLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj składnik'),
                ),
              ),
              const SizedBox(height: 12),

              Text('Instrukcje', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                'Przeciągnij za uchwyt, aby zmienić kolejność',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _reorderSteps,
                children: [
                  for (var i = 0; i < _stepControllers.length; i++) _buildStepRow(i),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('Dodaj krok'),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _commentsController,
                decoration: const InputDecoration(labelText: 'Komentarz'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              Text('Tagi', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              EditableChipList(
                items: _tags,
                onRemove: _removeTag,
                newItemController: _newTagController,
                onAdd: _addTag,
                addFieldLabel: 'Nowy tag',
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
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
