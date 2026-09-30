import 'package:flutter/material.dart';

import '../models/category.dart';
import 'ingredient_fields_section.dart';

// Whether the user is adding a new subcategory or a new ingredient under
// the dialog's (fixed) destination category.
enum TemplateNodeKind { category, ingredient }

// What AddTemplateNodeDialog hands back when the user taps "Dodaj": enough
// information for the caller to build either a new Category or a new
// Ingredient - the caller already knows where it goes, since that's the
// exact category the dialog was opened for (see TemplateContentScreen's
// _quickAddAt).
class AddTemplateNodeResult {
  final TemplateNodeKind kind;
  final String name;

  // Only meaningful when kind == TemplateNodeKind.ingredient.
  final String producer;
  final String description;
  final int bottlesCount;
  final List<String> tags;

  const AddTemplateNodeResult({
    required this.kind,
    required this.name,
    this.producer = '',
    this.description = '',
    this.bottlesCount = 0,
    this.tags = const [],
  });
}

// ============================================================================
// AddTemplateNodeDialog
// ----------------------------------------------------------------------------
// The quick "+" add flow, opened from a specific category's action row in
// the template tree: a name, a category-vs-ingredient type switch, and -
// only once "Składnik" is chosen - the same producer/description/bottle
// count/tags fields used when editing an ingredient (see
// IngredientFieldsSection). Unlike the old version of this dialog, there's
// no destination picker here - `destination` is fixed to whichever
// category's "+" button the user tapped, which is shown read-only for
// context.
// ============================================================================
class AddTemplateNodeDialog extends StatefulWidget {
  final Category destination;

  // The whole template's category tree, used only to collect existing tags
  // for the tag field's autocomplete/typo-suggestion UI (see
  // IngredientFieldsSection) - not for picking a destination, which is
  // fixed to `destination` above.
  final List<Category> allCategories;

  const AddTemplateNodeDialog({
    required this.destination,
    required this.allCategories,
    super.key,
  });

  @override
  State<AddTemplateNodeDialog> createState() => _AddTemplateNodeDialogState();
}

class _AddTemplateNodeDialogState extends State<AddTemplateNodeDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _producerController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _newTagController;

  TemplateNodeKind _kind = TemplateNodeKind.category;
  int _bottlesCount = 0;
  List<String> _tags = [];

  // Tags guessed from sibling ingredients already in `widget.destination` -
  // see suggestTagsForNewIngredient(). Computed once when the dialog opens;
  // accepting or rejecting one just removes it from this list (accepting
  // also adds it to _tags - see _acceptSuggestedTag below).
  late List<String> _suggestedTags;

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
    _suggestedTags = suggestTagsForNewIngredient(widget.destination);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

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

  // A suggested tag being accepted means "yes, use it" - it moves from the
  // suggested row into the real tag list, reusing _addTag so it still goes
  // through the normal empty/duplicate checks.
  void _acceptSuggestedTag(String tag) {
    setState(() => _suggestedTags = _suggestedTags.where((t) => t != tag).toList());
    _newTagController.text = tag;
    _addTag();
  }

  // Rejecting a suggestion just removes it from the suggested row - it was
  // never a real tag, so there's nothing else to undo.
  void _rejectSuggestedTag(String tag) {
    setState(() => _suggestedTags = _suggestedTags.where((t) => t != tag).toList());
  }

  void _save() {
    if (!_canSave) return;

    Navigator.pop(
      context,
      AddTemplateNodeResult(
        kind: _kind,
        name: _nameController.text.trim(),
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
              Text(
                'Do: ${widget.destination.name}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),

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
                    label: Text('Podkategoria'),
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

              // Only ingredients carry these extra fields - a category is
              // fully described by just its name and (fixed) location
              // above.
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
                  tagSuggestions: collectAllTags(widget.allCategories),
                  suggestedTags: _suggestedTags,
                  onAcceptSuggestedTag: _acceptSuggestedTag,
                  onRejectSuggestedTag: _rejectSuggestedTag,
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
