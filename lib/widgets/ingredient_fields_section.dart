import 'package:flutter/material.dart';

import 'editable_chip_list.dart';
import 'suggested_tags_row.dart';

// ============================================================================
// IngredientFieldsSection
// ----------------------------------------------------------------------------
// The producer/description fields, the +/- bottle count stepper, and the
// tag editor (removable chips + inline "add tag" field) - the set of
// ingredient detail fields shared by both EditTemplateIngredientDialog and
// AddTemplateNodeDialog. Purely presentational: it holds no state of its
// own, just renders whatever the caller passes in and reports changes back
// through callbacks, so each dialog keeps owning its own form state.
// ============================================================================
class IngredientFieldsSection extends StatelessWidget {
  final TextEditingController producerController;
  final TextEditingController descriptionController;

  final int bottlesCount;
  final VoidCallback onIncrementBottles;
  // Null disables the minus button - used to stop the count going below 0.
  final VoidCallback? onDecrementBottles;

  final List<String> tags;
  final TextEditingController newTagController;
  final VoidCallback onAddTag;
  final ValueChanged<String> onRemoveTag;

  // Every tag already in use elsewhere (e.g. across all ingredients in the
  // current template), feeding the tag field's autocomplete/typo-suggestion
  // UI - see EditableChipList. Defaults to empty, which just means no
  // suggestions are offered.
  final List<String> tagSuggestions;

  // Tags the app has *guessed* might fit this ingredient (see
  // suggestTagsForNewIngredient() in lib/models/category.dart), shown above
  // the real tag list until the user accepts or rejects each one - see
  // SuggestedTagsRow. Defaults to empty, which hides that row entirely (this
  // is only wired up for the "add new ingredient" flow, not editing).
  final List<String> suggestedTags;
  final ValueChanged<String>? onAcceptSuggestedTag;
  final ValueChanged<String>? onRejectSuggestedTag;

  const IngredientFieldsSection({
    required this.producerController,
    required this.descriptionController,
    required this.bottlesCount,
    required this.onIncrementBottles,
    required this.onDecrementBottles,
    required this.tags,
    required this.newTagController,
    required this.onAddTag,
    required this.onRemoveTag,
    this.tagSuggestions = const [],
    this.suggestedTags = const [],
    this.onAcceptSuggestedTag,
    this.onRejectSuggestedTag,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: producerController,
          decoration: const InputDecoration(labelText: 'Producent'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: descriptionController,
          decoration: const InputDecoration(labelText: 'Opis'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Bottle count stepper: minus / count / plus, rather than a
        // freeform text field the user has to type a number into.
        Row(
          children: [
            const Text('Liczba butelek'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Mniej',
              onPressed: onDecrementBottles,
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$bottlesCount',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Więcej',
              onPressed: onIncrementBottles,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Suggested tags sit above the real tag list, and only render at
        // all once there's something to suggest - see SuggestedTagsRow.
        if (suggestedTags.isNotEmpty) ...[
          Text('Sugerowane tagi', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SuggestedTagsRow(
            suggestions: suggestedTags,
            onAccept: onAcceptSuggestedTag ?? (_) {},
            onReject: onRejectSuggestedTag ?? (_) {},
          ),
          const SizedBox(height: 12),
        ],

        Text('Tagi', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        EditableChipList(
          items: tags,
          onRemove: onRemoveTag,
          newItemController: newTagController,
          onAdd: onAddTag,
          addFieldLabel: 'Nowy tag',
          suggestions: tagSuggestions,
        ),
      ],
    );
  }
}
