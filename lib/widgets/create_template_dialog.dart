import 'package:flutter/material.dart';

import 'editable_chip_list.dart';

// What CreateTemplateDialog hands back when the user taps "Utwórz": the
// name for the new template plus the (possibly empty) list of top-level
// category names to seed it with. Nothing else - no subcategories, no
// ingredients yet; those get added afterwards via the normal template
// editor (TemplateContentScreen).
class CreateTemplateResult {
  final String name;
  final List<String> categoryNames;

  const CreateTemplateResult({required this.name, required this.categoryNames});
}

// ============================================================================
// CreateTemplateDialog
// ----------------------------------------------------------------------------
// Deliberately minimal, per the "nothing more" brief: a name field and a
// flat list of category names to start the new template with (reusing
// EditableChipList - the same removable-chips-plus-add-field pattern used
// for tags elsewhere). No destination picker, no subcategories, no
// ingredients - those all come later through the normal editor once the
// template exists.
// ============================================================================
class CreateTemplateDialog extends StatefulWidget {
  const CreateTemplateDialog({super.key});

  @override
  State<CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<CreateTemplateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _newCategoryController;
  List<String> _categoryNames = [];

  @override
  void initState() {
    super.initState();
    _newCategoryController = TextEditingController();
    // Rebuilds the dialog as the user types, so the "Utwórz" button's
    // enabled/disabled state (see _canSave) stays in sync with whether a
    // name has actually been entered yet.
    _nameController = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  void _addCategory() {
    final name = _newCategoryController.text.trim();
    // Silently ignore blank input and exact duplicates instead of adding a
    // confusing second copy of the same category.
    if (name.isEmpty || _categoryNames.contains(name)) {
      _newCategoryController.clear();
      return;
    }
    setState(() {
      _categoryNames = [..._categoryNames, name];
      _newCategoryController.clear();
    });
  }

  void _removeCategory(String name) {
    setState(() => _categoryNames = _categoryNames.where((c) => c != name).toList());
  }

  void _save() {
    if (!_canSave) return;

    Navigator.pop(
      context,
      CreateTemplateResult(name: _nameController.text.trim(), categoryNames: _categoryNames),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nowy zestaw składników'),
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
                decoration: const InputDecoration(labelText: 'Nazwa zestawu'),
              ),
              const SizedBox(height: 16),
              Text('Kategorie', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              EditableChipList(
                items: _categoryNames,
                onRemove: _removeCategory,
                newItemController: _newCategoryController,
                onAdd: _addCategory,
                addFieldLabel: 'Nowa kategoria',
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
          child: const Text('Utwórz'),
        ),
      ],
    );
  }
}
