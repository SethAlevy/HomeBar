import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import '../services/file_handler.dart';
import '../services/auth.dart';

// Form screen used for both creating and editing ingredients.
class EditIngredientScreen extends StatefulWidget {
  // Existing item to edit; null means "create new" mode.
  final Ingredient? ingredient;

  // Full category tree that will be updated and persisted.
  final List<Category> allCategories;

  // Preferred category for inserting new ingredient.
  final String? targetCategoryName;

  const EditIngredientScreen({
    super.key,
    this.ingredient,
    required this.allCategories,
    this.targetCategoryName,
  });

  @override
  State<EditIngredientScreen> createState() => _EditIngredientScreenState();
}

class _EditIngredientScreenState extends State<EditIngredientScreen> {
  // Used to validate required fields before submit.
  final _formKey = GlobalKey<FormState>();

  // Controllers keep text field values and let us read them on submit.
  late TextEditingController _nameController;
  late TextEditingController _producerController;
  late TextEditingController _descriptionController;
  late TextEditingController _bottlesCountController;
  late TextEditingController _tagsController;

  // Separate controller for password dialog input.
  final TextEditingController _passwordController = TextEditingController();

  // True when editing existing item, false when creating new one.
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    // If ingredient is provided, prefill form with existing values.
    _isEditing = widget.ingredient != null;
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _producerController = TextEditingController(text: widget.ingredient?.producer ?? '');
    _descriptionController = TextEditingController(text: widget.ingredient?.description ?? '');
    _bottlesCountController = TextEditingController(
      text: widget.ingredient?.bottlesCount.toString() ?? '0',
    );
    _tagsController = TextEditingController(
      text: widget.ingredient?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    // Always dispose controllers in StatefulWidget to avoid memory leaks.
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _bottlesCountController.dispose();
    _tagsController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Validates form, verifies password, updates category tree, and persists data.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Ask for password before allowing write operations.
    final password = await _showPasswordDialog(context);
    if (password == null) return;

    final isPasswordCorrect = await Auth.checkPassword(password);
    if (!isPasswordCorrect) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password!')),
      );
      return;
    }

    // Convert bottle count safely and enforce non-negative values.
    final bottlesCount = int.tryParse(_bottlesCountController.text);
    if (bottlesCount == null || bottlesCount < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottles count must be a non-negative number.')),
      );
      return;
    }

    // Build Ingredient object from form values.
    final newIngredient = Ingredient(
      name: _nameController.text.trim(),
      producer: _producerController.text.trim(),
      description: _descriptionController.text.trim(),
      bottlesCount: bottlesCount,
      // User types comma-separated tags; normalize whitespace and drop empty ones.
      tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );

    // Apply add/update in a pure-tree transformation.
    final updatedCategories = _upsertIngredientInTree(
      widget.allCategories,
      original: widget.ingredient,
      replacement: newIngredient,
      preferredCategoryName: widget.targetCategoryName,
    );

    // Persist whole tree snapshot.
    await FileHandler.saveCategories(updatedCategories);

    if (!mounted) return;
    // Return to previous screen with created/updated object as result payload.
    Navigator.pop(context, newIngredient);
  }

  // Recursively updates an existing ingredient or inserts a new one.
  //
  // Strategy:
  // 1) If editing: locate by (name + producer) and replace.
  // 2) If adding: insert into preferred category when available.
  // 3) Fallback: insert into first top-level category.
  List<Category> _upsertIngredientInTree(
    List<Category> categories, {
    required Ingredient? original,
    required Ingredient replacement,
    required String? preferredCategoryName,
  }) {
    bool replaced = false;
    bool inserted = false;

    // Depth-first recursive rebuild of category nodes.
    Category walk(Category category) {
      final localIngredients = List<Ingredient>.from(category.ingredients);

      if (original != null) {
        // Basic identity rule for "same" ingredient in current implementation.
        final index = localIngredients.indexWhere(
          (i) => i.name == original.name && i.producer == original.producer,
        );
        if (index != -1) {
          localIngredients[index] = replacement;
          replaced = true;
        }
      }

      final localSubcategories = category.subcategories.map(walk).toList();

      if (!replaced && !inserted && preferredCategoryName != null && category.name == preferredCategoryName) {
        // For creation flow: add to requested category exactly once.
        localIngredients.add(replacement);
        inserted = true;
      }

      return category.copyWith(
        ingredients: localIngredients,
        subcategories: localSubcategories,
      );
    }

    final updated = categories.map(walk).toList();

    if (!replaced && !inserted && updated.isNotEmpty) {
      // Last-resort insertion to avoid dropping user input.
      final first = updated.first;
      final firstIngredients = List<Ingredient>.from(first.ingredients)..add(replacement);
      updated[0] = first.copyWith(ingredients: firstIngredients);
    }

    return updated;
  }

  // Prompts for password and returns entered value.
  // Returns null when cancelled.
  Future<String?> _showPasswordDialog(BuildContext context) async {
    _passwordController.clear();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Password'),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _passwordController.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _producerController,
                decoration: const InputDecoration(labelText: 'Producer'),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextFormField(
                controller: _bottlesCountController,
                decoration: const InputDecoration(labelText: 'Bottles Count'),
                keyboardType: TextInputType.number,
                // Minimal validation here; full numeric validation runs in _submit.
                validator: (value) => value?.trim().isEmpty ?? true ? 'Required' : null,
              ),
              TextFormField(
                controller: _tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma-separated)',
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Update' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
