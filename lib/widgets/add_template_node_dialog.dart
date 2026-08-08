import 'package:flutter/material.dart';

import '../models/category.dart';
import 'category_path_picker.dart';
import 'ingredient_fields_section.dart';

// Whether the user is adding a new category (which becomes a subcategory
// if a destination is picked, or a new top-level category if not) or a
// new ingredient (which always needs a destination category to live in).
enum TemplateNodeKind { category, ingredient }

// What AddTemplateNodeDialog hands back when the user taps "Dodaj": enough
// information for the caller to build either a new Category or a new
// Ingredient and insert it into the tree at `destination` (or at the top
// level, for a category, if `destination` is null).
class AddTemplateNodeResult {
  final TemplateNodeKind kind;
  final String name;
  final Category? destination;

  // Only meaningful when kind == TemplateNodeKind.ingredient.
  final String producer;
  final String description;
  final int bottlesCount;
  final List<String> tags;

  const AddTemplateNodeResult({
    required this.kind,
    required this.name,
    required this.destination,
    this.producer = '',
    this.description = '',
    this.bottlesCount = 0,
    this.tags = const [],
  });
}

// ============================================================================
// AddTemplateNodeDialog
// ----------------------------------------------------------------------------
// The single entry point for adding new content to a template, opened from
// the bottom bar's "Dodaj" button: a name, a category-vs-ingredient type
// switch, a destination picker (reusing CategoryPathPicker - the same tree
// used to move an existing ingredient), and - only once "Składnik" is
// chosen - the same producer/description/bottle-count/tags fields used
// when editing an ingredient (see IngredientFieldsSection).
// ============================================================================
class AddTemplateNodeDialog extends StatefulWidget {
  final List<Category> categories;

  const AddTemplateNodeDialog({required this.categories, super.key});

  @override
  State<AddTemplateNodeDialog> createState() => _AddTemplateNodeDialogState();
}

class _AddTemplateNodeDialogState extends State<AddTemplateNodeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _producerController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _newTagController;

  TemplateNodeKind _kind = TemplateNodeKind.category;
  Category? _destination;
  int _bottlesCount = 0;
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    _producerController = TextEditingController();
    _descriptionController = TextEditingController();
    _newTagController = TextEditingController();
    // Rebuilds the dialog as the user types, so the "Dodaj" button's
    // enabled/disabled state (see _canSave) stays in sync with whether a
    // name has actually been entered yet.
    _nameController = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  // A name is always required; an ingredient additionally needs somewhere
  // to live, since the data format has no concept of a "loose" ingredient
  // outside any category - a new category is allowed to have no
  // destination (it just becomes a top-level one instead).
  bool get _canSave {
    if (_nameController.text.trim().isEmpty) return false;
    if (_kind == TemplateNodeKind.ingredient && _destination == null) return false;
    return true;
  }

  void _changeBottles(int delta) {
    setState(() => _bottlesCount = (_bottlesCount + delta).clamp(0, 999));
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

    Navigator.pop(
      context,
      AddTemplateNodeResult(
        kind: _kind,
        name: _nameController.text.trim(),
        destination: _destination,
        producer: _producerController.text.trim(),
        description: _descriptionController.text.trim(),
        bottlesCount: _bottlesCount,
        tags: _tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIngredient = _kind == TemplateNodeKind.ingredient;

    return AlertDialog(
      title: const Text('Dodaj'),
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

              Text('Typ', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<TemplateNodeKind>(
                segments: const [
                  ButtonSegment(
                    value: TemplateNodeKind.category,
                    label: Text('Kategoria'),
                    icon: Icon(Icons.folder_outlined),
                  ),
                  ButtonSegment(
                    value: TemplateNodeKind.ingredient,
                    label: Text('Składnik'),
                    icon: Icon(Icons.liquor_outlined),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => setState(() => _kind = selection.first),
              ),
              const SizedBox(height: 16),

              Text('Lokalizacja', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              CategoryPathPicker(
                categories: widget.categories,
                selected: _destination,
                // A category with no chosen destination just becomes a new
                // top-level category; an ingredient always needs a real
                // destination (enforced by _canSave), so this option is
                // only offered while adding a category.
                allowTopLevel: _kind == TemplateNodeKind.category,
                onSelected: (category) => setState(() => _destination = category),
              ),
              if (isIngredient && _destination == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Wybierz kategorię dla nowego składnika.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),

              // Only ingredients carry these extra fields - a category is
              // fully described by just its name and location above.
              if (isIngredient) ...[
                const SizedBox(height: 16),
                IngredientFieldsSection(
                  producerController: _producerController,
                  descriptionController: _descriptionController,
                  bottlesCount: _bottlesCount,
                  onIncrementBottles: () => _changeBottles(1),
                  onDecrementBottles: _bottlesCount > 0 ? () => _changeBottles(-1) : null,
                  tags: _tags,
                  newTagController: _newTagController,
                  onAddTag: _addTag,
                  onRemoveTag: _removeTag,
                ),
              ],
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
          child: const Text('Dodaj'),
        ),
      ],
    );
  }
}
