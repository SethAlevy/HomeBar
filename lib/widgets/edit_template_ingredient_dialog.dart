import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/ingredient.dart';
import 'category_path_picker.dart';
import 'ingredient_fields_section.dart';

// What EditTemplateIngredientDialog hands back when the user taps "Zapisz":
// the edited Ingredient, plus which Category it should end up filed under
// (equal to the category it started in, unless the user picked a
// different one via "Przenieś do").
class EditIngredientDialogResult {
  final Ingredient ingredient;
  final Category destinationCategory;

  const EditIngredientDialogResult({
    required this.ingredient,
    required this.destinationCategory,
  });
}

// ============================================================================
// EditTemplateIngredientDialog
// ----------------------------------------------------------------------------
// Full edit form for one ingredient, shown as a modal dialog:
//   - "Przenieś do": an expandable tree of every category/subcategory
//     (labeled with its full path, e.g. "Alkohole/Mocne") for choosing
//     where this ingredient should live - see CategoryPathPicker.
//   - Editable name/producer/description fields, a bottle count stepper,
//     and a tag editor - see IngredientFieldsSection.
//
// It only builds and returns the *result* of the edit - the caller
// (TemplateContentScreen) is the one that actually moves the ingredient
// within the category tree and persists it, since that logic needs to see
// the whole tree, not just one ingredient.
// ============================================================================
class EditTemplateIngredientDialog extends StatefulWidget {
  final Ingredient ingredient;
  final List<Category> allCategories;
  final Category currentCategory;

  const EditTemplateIngredientDialog({
    required this.ingredient,
    required this.allCategories,
    required this.currentCategory,
    super.key,
  });

  @override
  State<EditTemplateIngredientDialog> createState() => _EditTemplateIngredientDialogState();
}

class _EditTemplateIngredientDialogState extends State<EditTemplateIngredientDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _producerController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _newTagController;

  late int _bottlesCount;
  late List<String> _tags;

  // Which category the ingredient will be filed under if the user saves.
  // Defaults to wherever it currently lives, so "Zapisz" without touching
  // "Przenieś do" leaves it in place.
  late Category _destinationCategory;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient.name);
    _producerController = TextEditingController(text: widget.ingredient.producer);
    _descriptionController = TextEditingController(text: widget.ingredient.description);
    _newTagController = TextEditingController();
    _bottlesCount = widget.ingredient.bottlesCount;
    _tags = List<String>.from(widget.ingredient.tags);
    _destinationCategory = widget.currentCategory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  void _changeBottles(int delta) {
    setState(() => _bottlesCount = (_bottlesCount + delta).clamp(0, 999));
  }

  void _addTag() {
    final tag = _newTagController.text.trim();
    // Silently ignore blank input and exact duplicates instead of adding a
    // confusing second copy of the same tag.
    if (tag.isEmpty || _tags.contains(tag)) {
      _newTagController.clear();
      return;
    }
    setState(() {
      _tags.add(tag);
      _newTagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _save() {
    // Name is required - an ingredient with no name would be unusable
    // everywhere else it's shown.
    if (_nameController.text.trim().isEmpty) return;

    final updated = Ingredient(
      name: _nameController.text.trim(),
      producer: _producerController.text.trim(),
      description: _descriptionController.text.trim(),
      bottlesCount: _bottlesCount,
      tags: _tags,
    );

    Navigator.pop(
      context,
      EditIngredientDialogResult(ingredient: updated, destinationCategory: _destinationCategory),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj składnik'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Przenieś do', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              CategoryPathPicker(
                categories: widget.allCategories,
                selected: _destinationCategory,
                // An existing ingredient must always stay filed under some
                // category - CategoryPathPicker only ever offers real
                // categories to pick from, so `category` is never null here.
                onSelected: (category) => setState(() => _destinationCategory = category!),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nazwa'),
              ),
              const SizedBox(height: 8),
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
          onPressed: _save,
          child: const Text('Zapisz'),
        ),
      ],
    );
  }
}
