import 'package:flutter/material.dart';

// ============================================================================
// EditableChipList
// ----------------------------------------------------------------------------
// A small, reusable "list of short text values you can add to and remove
// from" - existing items shown as removable chips, plus an inline text
// field + button to add a new one. Used for an ingredient's tags
// (IngredientFieldsSection) and for the category names typed while
// creating a brand-new template (CreateTemplateDialog) - both are really
// the same UI over a plain List<String>, just with a different label.
//
// Purely presentational: it holds no state of its own. The caller owns
// `items` and the text controller, and reacts to onAdd/onRemove by
// updating its own state - the same pattern as IngredientFieldsSection.
// ============================================================================
class EditableChipList extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String> onRemove;
  final TextEditingController newItemController;
  final VoidCallback onAdd;

  // Label shown on the "type a new one" field, e.g. "Nowy tag" or "Nowa
  // kategoria" - the only thing that differs between use sites.
  final String addFieldLabel;

  const EditableChipList({
    required this.items,
    required this.onRemove,
    required this.newItemController,
    required this.onAdd,
    required this.addFieldLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (items.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    // Built-in delete affordance - Chip draws an "x" and
                    // calls onDeleted when it's tapped.
                    onDeleted: () => onRemove(item),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: Colors.grey.shade200,
                    labelStyle: const TextStyle(color: Colors.black87),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 8),

        // Inline "add" row: type a value, then either press Enter or tap
        // the + button.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: newItemController,
                decoration: InputDecoration(labelText: addFieldLabel, isDense: true),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj',
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}
