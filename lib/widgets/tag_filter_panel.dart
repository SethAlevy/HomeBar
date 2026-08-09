import 'package:flutter/material.dart';

// ============================================================================
// TagFilterPanel
// ----------------------------------------------------------------------------
// A collapsible, multi-select tag filter shown below a search field (see
// IngredientsScreen/RecipesScreen). Collapsed by default so it stays out
// of the way until the user wants to filter by tag. "Zaznacz wszystko" is
// a toggle: it selects every tag (the neutral/default state, showing
// everything) or - if everything is already selected - clears the
// selection entirely, which callers should treat as "show nothing" rather
// than falling back to "no filter".
// ============================================================================
class TagFilterPanel extends StatelessWidget {
  // Shown in the collapsed header, e.g. "Filtruj po tagach".
  final String title;

  final List<String> allTags;
  final Set<String> selectedTags;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onToggleSelectAll;

  const TagFilterPanel({
    required this.title,
    required this.allTags,
    required this.selectedTags,
    required this.onToggleTag,
    required this.onToggleSelectAll,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Nothing to filter by - don't show an empty, pointless panel.
    if (allTags.isEmpty) return const SizedBox.shrink();

    final allSelected = selectedTags.length == allTags.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Theme(
        // Removes the faint divider ExpansionTile normally draws above and
        // below itself - purely cosmetic, keeps this compact panel tidy.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          // "Everything selected" is the neutral/default state, so it gets
          // the plain title; any other count (including 0, meaning the
          // list is showing nothing) is worth calling out.
          title: Text(allSelected ? title : '$title (${selectedTags.length})'),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // FilterChip already has built-in "selected" styling and
                  // an onSelected callback, so it doubles as a tap-to-
                  // toggle control - no separate Checkbox/Switch needed for
                  // either this or the tag chips below.
                  FilterChip(
                    label: const Text('Zaznacz wszystko'),
                    selected: allSelected,
                    onSelected: (_) => onToggleSelectAll(),
                  ),
                  ...allTags.map(
                    (tag) => FilterChip(
                      label: Text(tag),
                      selected: selectedTags.contains(tag),
                      onSelected: (_) => onToggleTag(tag),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
