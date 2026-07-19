import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import '../services/file_handler.dart';
import '../services/auth.dart';

class EditIngredientScreen extends StatefulWidget {
  final Ingredient? ingredient;
  final List<Category> allCategories;

  const EditIngredientScreen({
    super.key,
    this.ingredient,
    required this.allCategories,
  });

  @override
  State<EditIngredientScreen> createState() => _EditIngredientScreenState();
}

class _EditIngredientScreenState extends State<EditIngredientScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _producerController;
  late TextEditingController _descriptionController;
  late TextEditingController _bottlesCountController;
  late TextEditingController _tagsController;

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    _producerController.dispose();
    _descriptionController.dispose();
    _bottlesCountController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check password
    final password = await _showPasswordDialog(context);
    if (password == null) return;

    final isPasswordCorrect = await Auth.checkPassword(password);
    if (!isPasswordCorrect) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password!')),
      );
      return;
    }

    // Create or update ingredient
    final newIngredient = Ingredient(
      name: _nameController.text,
      producer: _producerController.text,
      description: _descriptionController.text,
      bottlesCount: int.tryParse(_bottlesCountController.text) ?? 0,
      tags: _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );

    // TODO: Add logic to update the ingredient in the correct category
    // For now, we'll just save all categories back to the file
    await FileHandler.saveCategories(widget.allCategories);

    Navigator.pop(context, newIngredient);
  }

  Future<String?> _showPasswordDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Password'),
        content: TextField(
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'admin123'), // Default password
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
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
                validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
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
