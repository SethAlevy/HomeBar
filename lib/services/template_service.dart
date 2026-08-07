import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart' as yaml;

import '../models/ingredient.dart';

// Which "kind" of template a TemplateFile is - used to sort bundled files
// into the right section of the UI (ingredient pickers vs. recipe pickers).
enum TemplateType { ingredient, recipe }

// A lightweight reference to a template file: just enough info (path, a
// human-friendly name, and its type) to show it in a list before the user
// has chosen to actually open/read it. Reading the full content only
// happens later, via loadTemplateTree() below.
class TemplateFile {
  final String path;
  final String name;
  final TemplateType type;

  const TemplateFile({
    required this.path,
    required this.name,
    required this.type,
  });
}

// Whether a node in a parsed template tree is a folder-like category or a
// leaf ingredient entry - lets the UI decide whether to render an
// expandable folder row or a plain ingredient tile.
enum TemplateNodeType { category, ingredient }

// One node in the tree produced by parsing a template's YAML content.
// Mirrors the shape of Category/Ingredient from lib/models, but flattened
// into a single generic tree type that's convenient for the UI to walk
// without caring whether it's looking at a category or an ingredient.
class TemplateTreeNode {
  final String title;
  final TemplateNodeType type;
  final List<TemplateTreeNode> children;

  // Only set when type == TemplateNodeType.ingredient - carries the full
  // parsed Ingredient so the UI can display every field (producer,
  // description, bottle count, tags), not just a name.
  final Ingredient? ingredient;

  const TemplateTreeNode({
    required this.title,
    required this.type,
    this.children = const [],
    this.ingredient,
  });
}

// ============================================================================
// TemplateService
// ----------------------------------------------------------------------------
// Reads the read-only template YAML files bundled under assets/data/ (as
// opposed to FileHandler, which reads/writes the user's live, editable
// data file). Used by the "Zarządzaj zestawami" (manage homebars) screens
// to let the user browse what starter content is available.
// ============================================================================
class TemplateService {
  // Scans the small, fixed set of known bundled template paths and returns
  // a TemplateFile entry for each one that actually exists and isn't
  // empty. (There's no directory-listing API for Flutter assets, so the
  // paths are checked one by one rather than discovered dynamically.)
  static Future<List<TemplateFile>> loadBundledTemplates() async {
    final templates = <TemplateFile>[];

    final ingredientContent = await _loadOptionalText(
      'assets/data/ingredient/ingredients.yaml',
    );
    if (ingredientContent != null && ingredientContent.trim().isNotEmpty) {
      templates.add(
        const TemplateFile(
          path: 'assets/data/ingredient/ingredients.yaml',
          name: 'Szablon składników',
          type: TemplateType.ingredient,
        ),
      );
    }

    final recipeContent = await _loadOptionalText(
      'assets/data/recipe/recipes.yaml',
    );
    if (recipeContent != null && recipeContent.trim().isNotEmpty) {
      templates.add(
        const TemplateFile(
          path: 'assets/data/recipe/recipes.yaml',
          name: 'Szablon przepisów',
          type: TemplateType.recipe,
        ),
      );
    }

    return templates;
  }

  // Reads a template file at `path` and parses its `categories` list into
  // a tree of TemplateTreeNode, ready for a tree-view widget to render.
  static Future<List<TemplateTreeNode>> loadTemplateTree(String path) async {
    final content = await _loadOptionalText(path);
    if (content == null || content.trim().isEmpty) {
      return [];
    }

    final data = yaml.loadYaml(content);
    if (data is! Map || data['categories'] is! List) {
      // Missing or malformed data - fail soft with an empty tree instead
      // of throwing, so the screen can show a "no content" message.
      return [];
    }

    return (data['categories'] as List)
        .whereType<Map>()
        .map((item) => _parseCategoryNode(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Reads a text file from either the bundled asset bundle (paths starting
  // with "assets/") or the real filesystem, returning null instead of
  // throwing when the file is missing or unreadable. Centralizing this
  // "try to read, otherwise null" pattern keeps the two callers above
  // simple.
  static Future<String?> _loadOptionalText(String path) async {
    try {
      if (path.startsWith('assets/')) {
        return await rootBundle.loadString(path);
      }

      final file = File(path);
      if (await file.exists()) {
        return await file.readAsString();
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  // Recursively converts one parsed YAML category map (and everything
  // nested inside it) into a TemplateTreeNode tree. This mirrors
  // Category.fromYaml()/Ingredient.fromYaml() in lib/models, but builds
  // the generic TemplateTreeNode shape instead, since the template viewer
  // UI wants a single node type it can render uniformly.
  static TemplateTreeNode _parseCategoryNode(Map<String, dynamic> data) {
    final children = <TemplateTreeNode>[];

    // Nested categories become child nodes first, so they appear above
    // this category's direct ingredients in the resulting tree.
    final subcategories = data['subcategories'];
    if (subcategories is List) {
      for (final item in subcategories) {
        if (item is Map) {
          children.add(_parseCategoryNode(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Direct ingredients become leaf nodes, each wrapping a fully parsed
    // Ingredient so the UI has every field available to display.
    final ingredients = data['ingredients'];
    if (ingredients is List) {
      for (final item in ingredients) {
        if (item is Map) {
          final ingredient = Ingredient.fromYaml(Map<String, dynamic>.from(item));

          children.add(
            TemplateTreeNode(
              title: ingredient.name,
              type: TemplateNodeType.ingredient,
              ingredient: ingredient,
            ),
          );
        }
      }
    }

    return TemplateTreeNode(
      title: data['name']?.toString() ?? 'Bez nazwy',
      type: TemplateNodeType.category,
      children: children,
    );
  }

  // Placeholder for "create a new ingredient template from scratch".
  // For now it just hands back the existing default template's info
  // rather than actually creating a new file - a stand-in until real
  // template creation is implemented.
  static Future<TemplateFile> createIngredientTemplate() async {
    return const TemplateFile(
      path: 'assets/data/ingredient/ingredients.yaml',
      name: 'Szablon składników',
      type: TemplateType.ingredient,
    );
  }
}
