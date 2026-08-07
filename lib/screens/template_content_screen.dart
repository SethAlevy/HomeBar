import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../services/template_service.dart';

// ============================================================================
// TemplateContentScreen
// ----------------------------------------------------------------------------
// Full-screen viewer for one template file (picked in ManageHomebarsScreen).
// Loads the file's parsed tree (categories + ingredients) and renders it as
// a fully expanded tree: categories as folders you can collapse, and
// ingredients as detail cards showing every field. All the edit/add/delete
// buttons on screen are placeholders for now - see _showDummySnackBar.
// ============================================================================
class TemplateContentScreen extends StatelessWidget {
  final TemplateFile template;

  const TemplateContentScreen({required this.template, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(template.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      // FutureBuilder runs an async operation (loading + parsing the YAML
      // file) and rebuilds this part of the UI as that Future's state
      // changes - "loading" while it's pending, then "has data" once it
      // resolves. It's the declarative alternative to manually calling
      // setState() from inside an async function.
      body: FutureBuilder<List<TemplateTreeNode>>(
        future: TemplateService.loadTemplateTree(template.path),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            // Covers both "still loading" and, in this simplified case,
            // errors - loadTemplateTree() is written to fail soft and
            // return [] rather than throw, so an actual error state
            // shouldn't normally reach here.
            return const Center(child: CircularProgressIndicator());
          }

          final nodes = snapshot.data!;
          if (nodes.isEmpty) {
            return const Center(child: Text('Brak zawartości szablonu.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            // depth: 0 because these are the top-level categories; each
            // nested level below increases depth by one (see
            // _TemplateTreeTile below), which drives the indentation.
            children: nodes
                .map((node) => _TemplateTreeTile(node: node, depth: 0))
                .toList(),
          );
        },
      ),
    );
  }
}

// Shared helper used by every placeholder button on this screen: shows a
// brief message instead of performing a real action. Centralizing it here
// means swapping in real edit/add/delete behavior later only requires
// changing the button callbacks, not this helper.
void _showDummySnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

// ============================================================================
// _TemplateTreeTile
// ----------------------------------------------------------------------------
// Renders one node of the template tree - recursively. A category node
// draws itself as an expandable folder containing its action buttons plus
// one _TemplateTreeTile per child (which might themselves be categories or
// ingredients); an ingredient node draws itself as a detail card via
// _IngredientTile. This recursion is what turns the flat TemplateTreeNode
// tree into nested, indented widgets on screen.
// ============================================================================
class _TemplateTreeTile extends StatelessWidget {
  final TemplateTreeNode node;

  // How many levels deep in the tree this node is - 0 for a top-level
  // category, 1 for its direct children, and so on. Used purely to
  // compute left indentation below.
  final int depth;

  const _TemplateTreeTile({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    // Each level of depth pushes the row 16 logical pixels further right,
    // which is what makes the nested structure visually read as a tree.
    final indent = EdgeInsets.only(left: depth * 16.0);

    if (node.type == TemplateNodeType.category) {
      return Padding(
        padding: indent,
        child: Theme(
          // Wrapping in a local Theme override removes the faint divider
          // line ExpansionTile normally draws above/below itself when
          // expanded - purely cosmetic, so nested tiles look cleaner.
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            // Always start expanded, per the "show the full expanded tree
            // up front" requirement - the user can still tap to collapse
            // individual branches afterwards.
            initiallyExpanded: true,
            leading: const Icon(Icons.folder_outlined),
            title: Text(
              node.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            children: [
              // The action row (edit/add subcategory/add ingredient/
              // delete) is the first thing shown once expanded, above
              // this category's actual children.
              _CategoryActionsRow(categoryName: node.title),
              // Spread operator inlines one _TemplateTreeTile per child
              // node directly into this children list. Each recurses with
              // depth + 1, so grandchildren indent further than children.
              ...node.children.map(
                (child) => _TemplateTreeTile(node: child, depth: depth + 1),
              ),
            ],
          ),
        ),
      );
    }

    // Non-category nodes are always ingredient leaves (see
    // TemplateNodeType) and always carry a parsed Ingredient - the `!`
    // asserts that non-null-ness, which TemplateService guarantees when
    // it builds these nodes.
    return Padding(
      padding: indent,
      child: _IngredientTile(ingredient: node.ingredient!),
    );
  }
}

// The row of placeholder action buttons shown at the top of every expanded
// category: edit this category, add a subcategory under it, add an
// ingredient directly to it, or delete it. None of these do anything real
// yet - each just reports what it *would* do via a SnackBar.
class _CategoryActionsRow extends StatelessWidget {
  final String categoryName;

  const _CategoryActionsRow({required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Wrap(
        // Wrap (rather than Row) lets the buttons flow onto a second line
        // automatically if the screen is too narrow to fit all four.
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edytuj kategorię',
            onPressed: () =>
                _showDummySnackBar(context, 'Edytuj kategorię "$categoryName" — wkrótce dostępne'),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Dodaj podkategorię',
            onPressed: () =>
                _showDummySnackBar(context, 'Dodaj podkategorię do "$categoryName" — wkrótce dostępne'),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Dodaj składnik',
            onPressed: () =>
                _showDummySnackBar(context, 'Dodaj składnik do "$categoryName" — wkrótce dostępne'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Usuń kategorię',
            // Using the theme's error color signals "destructive action"
            // the same way delete buttons do elsewhere in Material Design.
            color: Theme.of(context).colorScheme.error,
            onPressed: () =>
                _showDummySnackBar(context, 'Usuń kategorię "$categoryName" — wkrótce dostępne'),
          ),
        ],
      ),
    );
  }
}

// A detail card for one ingredient leaf: icon, name, producer,
// description, bottle count, and its tags as chips, plus placeholder
// edit/delete buttons. This is deliberately richer than a plain
// ListTile(title: ...) so every field the Ingredient model carries is
// actually visible here, not just its name.
class _IngredientTile extends StatelessWidget {
  final Ingredient ingredient;

  const _IngredientTile({required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          // Align to the top of the row so the leading icon and the
          // action buttons line up with the *first* line of text even
          // when the description wraps to multiple lines.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.inventory_2_outlined),
            ),
            const SizedBox(width: 12),
            // Expanded makes this column claim all the space between the
            // leading icon and the trailing buttons, so long descriptions
            // wrap instead of overflowing the card.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  // Each optional field below only renders if it actually
                  // has content, so blank producer/description fields
                  // don't leave empty gaps in the card.
                  if (ingredient.producer.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        ingredient.producer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (ingredient.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(ingredient.description),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_bar_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text('${ingredient.bottlesCount} but.'),
                      ],
                    ),
                  ),
                  if (ingredient.tags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        // Both spacing (horizontal, between chips on the
                        // same line) and runSpacing (vertical, between
                        // wrapped lines) keep the chip cloud readable no
                        // matter how many tags there are.
                        spacing: 6,
                        runSpacing: 6,
                        children: ingredient.tags
                            .map(
                              (tag) => Chip(
                                label: Text(tag),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edytuj składnik',
              onPressed: () =>
                  _showDummySnackBar(context, 'Edytuj "${ingredient.name}" — wkrótce dostępne'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Usuń składnik',
              color: Theme.of(context).colorScheme.error,
              onPressed: () =>
                  _showDummySnackBar(context, 'Usuń "${ingredient.name}" — wkrótce dostępne'),
            ),
          ],
        ),
      ),
    );
  }
}
