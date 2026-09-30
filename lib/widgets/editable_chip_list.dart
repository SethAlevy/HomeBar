import 'package:flutter/material.dart';

import '../utils/levenshtein.dart';
import '../utils/polish_text.dart';

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
// Almost entirely presentational: the caller owns `items` and the text
// controller, and reacts to onAdd/onRemove by updating its own state - the
// same pattern as IngredientFieldsSection. The only state this widget keeps
// for itself is the FocusNode the autocomplete field below needs, which is
// purely an implementation detail of how it's rendered.
//
// `suggestions` is optional and opt-in: when the caller passes the full
// list of values already in use elsewhere (e.g. every tag across all
// ingredients), the add field turns into an autocomplete that offers
// matching existing values as the user types. If what's typed still isn't
// an exact match for anything, tapping "add" triggers a "did you mean...?"
// confirmation dialog instead of adding it outright - see _handleAdd()
// below. Leaving `suggestions` empty (the default) reduces this back to a
// plain text field with no autocomplete or typo-checking, which is what
// CreateTemplateDialog's category-name use still gets.
// ============================================================================
class EditableChipList extends StatefulWidget {
  final List<String> items;
  final ValueChanged<String> onRemove;
  final TextEditingController newItemController;
  final VoidCallback onAdd;

  // Label shown on the "type a new one" field, e.g. "Nowy tag" or "Nowa
  // kategoria" - the only thing that differs between use sites.
  final String addFieldLabel;

  // Existing values to suggest from (see class comment above).
  final List<String> suggestions;

  const EditableChipList({
    required this.items,
    required this.onRemove,
    required this.newItemController,
    required this.onAdd,
    required this.addFieldLabel,
    this.suggestions = const [],
    super.key,
  });

  @override
  State<EditableChipList> createState() => _EditableChipListState();
}

class _EditableChipListState extends State<EditableChipList> {
  // Autocomplete requires an explicit FocusNode whenever it's given an
  // external TextEditingController (as opposed to creating its own of
  // each), and that FocusNode needs a stable owner - creating a fresh one
  // on every build would drop keyboard focus each time this widget
  // rebuilds (e.g. right after adding a tag).
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // Fills the field with `value` and adds it straight away - used when the
  // user picks an option from the autocomplete dropdown, since that's
  // already an explicit, unambiguous choice (no typo check needed).
  void _acceptSuggestion(String value) {
    widget.newItemController.text = value;
    widget.onAdd();
  }

  // Called when the user taps the "+" button or presses Enter in the field.
  // Before actually adding the typed text as a new tag, this checks whether
  // it looks like a typo of something that already exists (see
  // _findTypoSuggestion below) - if so, it asks for confirmation first
  // instead of silently creating what might be a duplicate, misspelled tag.
  Future<void> _handleAdd() async {
    final typo = _findTypoSuggestion(widget.newItemController.text, widget.suggestions, widget.items);
    if (typo == null) {
      // Nothing close enough to be worth asking about - add exactly what
      // was typed, same as before.
      widget.onAdd();
      return;
    }

    final typedValue = widget.newItemController.text.trim();
    // barrierDismissible: false - tapping outside this dialog should not
    // silently do nothing. The user must pick one of the two options below,
    // so it's always clear what ended up happening.
    final useSuggestion = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Czy chodziło Ci o...?'),
        content: Text('Wpisano "$typedValue". Czy chodziło Ci o "$typo"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Zachowaj "$typedValue"'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Użyj "$typo"'),
          ),
        ],
      ),
    );

    if (useSuggestion == true) {
      widget.newItemController.text = typo;
    }
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final onRemove = widget.onRemove;
    final newItemController = widget.newItemController;
    final addFieldLabel = widget.addFieldLabel;
    final suggestions = widget.suggestions;

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

        // "Add" row: type a value, then either press Enter or tap the +
        // button - both go through _handleAdd(), which is what decides
        // whether a typo-confirmation dialog is needed first (see above).
        // Wrapped in Autocomplete so that - only when the caller supplied
        // `suggestions` - matching existing values show up as a tappable
        // dropdown while typing.
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                textEditingController: newItemController,
                focusNode: _focusNode,
                optionsBuilder: (textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return const Iterable<String>.empty();
                  return suggestions.where(
                    (suggestion) =>
                        !items.contains(suggestion) && suggestion.toLowerCase().contains(query),
                  );
                },
                onSelected: _acceptSuggestion,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(labelText: addFieldLabel, isDense: true),
                    onSubmitted: (_) => _handleAdd(),
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Dodaj',
              onPressed: _handleAdd,
            ),
          ],
        ),
      ],
    );
  }
}

// Looks for an existing value that's a likely typo of what's currently
// typed: close enough in edit distance to probably be the same word
// misspelled, or already in the list (nothing to suggest - it's already
// added). Only called when the user actually tries to add the typed text
// (see _handleAdd above), not on every keystroke.
//
// Comparisons run on text with Polish diacritics stripped (see
// stripPolishDiacritics) so that typing a word without its accents - e.g.
// "pomaranczowy" instead of "pomarańczowy" - is recognized as the same word
// (edit distance 0) rather than a completely different one.
String? _findTypoSuggestion(String input, List<String> suggestions, List<String> items) {
  final query = input.trim();
  if (query.isEmpty) return null;
  final normalizedQuery = stripPolishDiacritics(query).toLowerCase();

  String? bestMatch;
  var bestDistance = 1 << 30;

  for (final suggestion in suggestions) {
    if (items.contains(suggestion)) continue;
    // Already exactly what's typed (diacritics and all) - nothing to fix.
    if (suggestion.toLowerCase() == query.toLowerCase()) continue;

    final normalizedSuggestion = stripPolishDiacritics(suggestion).toLowerCase();
    final distance = levenshteinDistance(normalizedQuery, normalizedSuggestion);
    // Tolerance scales with word length: short tags need a near-exact
    // match (one typo'd letter) while longer ones allow a bit more slack.
    final maxAllowedDistance = normalizedQuery.length <= 4 ? 1 : 2;
    if (distance <= maxAllowedDistance && distance < bestDistance) {
      bestDistance = distance;
      bestMatch = suggestion;
    }
  }

  return bestMatch;
}
