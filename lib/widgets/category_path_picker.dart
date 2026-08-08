import 'package:flutter/material.dart';

import '../models/category.dart';

// ============================================================================
// CategoryPathPicker
// ----------------------------------------------------------------------------
// A bordered, scrollable, expandable tree of every category and
// subcategory, each labeled with its full path (e.g. "Alkohole/Mocne").
// Shared by every dialog that needs to pick an existing category: moving
// an ingredient to a different one, or choosing where a newly added
// category/ingredient should live.
// ============================================================================
class CategoryPathPicker extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category?> onSelected;

  // Shows an extra "Poziom główny" (top level) row above the tree that
  // selects `null` - i.e. "no parent category". Only meaningful when
  // adding a brand-new top-level category; an existing ingredient always
  // has to live inside some category, so callers editing one should leave
  // this false (the default).
  final bool allowTopLevel;

  const CategoryPathPicker({
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.allowTopLevel = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allowTopLevel)
              _SelectableRow(
                label: 'Poziom główny',
                isSelected: selected == null,
                onTap: () => onSelected(null),
              ),
            ...categories.map(
              (category) => _CategoryPathNode(
                category: category,
                pathPrefix: '',
                selected: selected,
                onSelected: onSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A plain, non-expandable selectable row - used only for the "Poziom
// główny" pseudo-option above, which has no path or children of its own.
class _SelectableRow extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableRow({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18,
                color: isSelected ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}

// One row in the tree, built by hand instead of with ExpansionTile: a
// category with subcategories still needs to be *selectable* on its own
// (e.g. an ingredient can live directly under "Alkohole" even though
// "Alkohole" also has children) - so selecting and expanding are two
// separate tap targets, rather than ExpansionTile's single "tap toggles
// expansion" behavior.
class _CategoryPathNode extends StatefulWidget {
  final Category category;
  final String pathPrefix;
  final Category? selected;
  final ValueChanged<Category?> onSelected;

  const _CategoryPathNode({
    required this.category,
    required this.pathPrefix,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CategoryPathNode> createState() => _CategoryPathNodeState();
}

class _CategoryPathNodeState extends State<_CategoryPathNode> {
  // Starts expanded so the whole tree is visible up front, consistent
  // with how the main template viewer starts fully expanded too.
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final path = widget.pathPrefix.isEmpty
        ? widget.category.name
        : '${widget.pathPrefix}/${widget.category.name}';

    // identical() (reference equality) rather than name comparison: callers
    // pass the exact same Category objects held in the screen's state, so
    // this is an unambiguous "is this THE selected node" check even if two
    // categories happen to share a name.
    final isSelected = widget.selected != null && identical(widget.category, widget.selected);
    final hasChildren = widget.category.subcategories.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
          child: InkWell(
            onTap: () => widget.onSelected(widget.category),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 18,
                    color: isSelected ? scheme.primary : scheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(path)),
                  // Only categories with subcategories get an expand
                  // control; leaf categories have nothing to reveal.
                  if (hasChildren)
                    IconButton(
                      icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                      visualDensity: VisualDensity.compact,
                      tooltip: _expanded ? 'Zwiń' : 'Rozwiń',
                      onPressed: () => setState(() => _expanded = !_expanded),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && _expanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.category.subcategories
                  .map(
                    (sub) => _CategoryPathNode(
                      category: sub,
                      pathPrefix: path,
                      selected: widget.selected,
                      onSelected: widget.onSelected,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
