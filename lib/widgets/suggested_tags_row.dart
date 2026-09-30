import 'package:flutter/material.dart';

// ============================================================================
// SuggestedTagsRow
// ----------------------------------------------------------------------------
// Shows tags the app has *guessed* might fit a new ingredient (see
// suggestTagsForNewIngredient() in lib/models/category.dart), without
// actually adding any of them yet. Each suggestion is drawn as a muted,
// greyed-out chip - visually different from the normal (confirmed) tag
// chips in EditableChipList - with two small icon buttons:
//   - a check mark, which "accepts" the suggestion (promotes it to a real,
//     confirmed tag)
//   - an X, which "rejects" it (just removes it from this suggested row;
//     it is never added as a tag)
// Purely presentational, like EditableChipList: the caller owns the actual
// list of suggestions and reacts to onAccept/onReject by updating its own
// state.
// ============================================================================
class SuggestedTagsRow extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  const SuggestedTagsRow({
    required this.suggestions,
    required this.onAccept,
    required this.onReject,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing left to suggest (none computed, or the user already accepted
    // or rejected all of them) - don't show an empty row.
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: suggestions
          .map(
            (tag) => Container(
              padding: const EdgeInsets.only(left: 10, right: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tag, style: TextStyle(color: Colors.grey.shade700)),
                  IconButton(
                    icon: const Icon(Icons.check, size: 16, color: Colors.green),
                    tooltip: 'Zaakceptuj sugestię',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onAccept(tag),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    tooltip: 'Odrzuć sugestię',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onReject(tag),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
