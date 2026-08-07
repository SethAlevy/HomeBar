import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart' as yaml;

import '../models/category.dart';

// ============================================================================
// FileHandler
// ----------------------------------------------------------------------------
// This service owns reading and writing the user's *live* ingredient data -
// as opposed to TemplateService, which only reads the read-only bundled
// template files. Concretely, it manages one YAML file
// (`ingredients.yaml`) that lives in the app's private documents folder on
// the device, which is separate from the app's bundled `assets/` folder:
//   - `assets/` ships inside the app package and is read-only at runtime.
//   - the documents directory is writable and persists between app runs.
//
// The very first time the app runs, there is no such file yet, so
// loadCategories() seeds it by copying the bundled default template.
// ============================================================================
class FileHandler {
  // Name of the file we read/write in the app's documents directory.
  static const _fileName = 'ingredients.yaml';

  // Bundled asset used to seed a brand-new install with starter data.
  static const _defaultIngredientTemplate =
      'assets/data/ingredient/ingredients.yaml';

  // Resolves the full, platform-correct path to our data file and wraps it
  // in a File object. getApplicationDocumentsDirectory() returns a
  // per-app, per-device folder guaranteed to be writable.
  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  // Loads the full category tree from disk, creating the file from the
  // bundled default template first if it doesn't exist yet (first run).
  static Future<List<Category>> loadCategories() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        // First run (or the file was deleted): seed it from the read-only
        // asset bundled with the app, so the user has starter data instead
        // of an empty list.
        final defaultContent = await rootBundle.loadString(
          _defaultIngredientTemplate,
        );
        await file.writeAsString(defaultContent);
      }

      final content = await file.readAsString();
      final data = yaml.loadYaml(content);

      // Defensive check: if the file is malformed or missing the expected
      // top-level `categories` list, fail soft with an empty list instead
      // of throwing and crashing the screen that called this.
      if (data is! Map || data['categories'] is! List) {
        return [];
      }

      return (data['categories'] as List)
          .map((category) => Category.fromYaml(
                Map<String, dynamic>.from(category as Map),
              ))
          .toList();
    } catch (_) {
      // Any unexpected error (bad file permissions, corrupt YAML, etc.)
      // also falls back to an empty list rather than propagating an
      // exception up into the UI layer.
      return [];
    }
  }

  // Persists the given category tree back to disk, fully overwriting the
  // previous contents of the file (this is a "save everything" operation,
  // not an incremental update).
  static Future<void> saveCategories(List<Category> categories) async {
    final file = await _getFile();
    final data = {'categories': categories.map((e) => e.toYaml()).toList()};
    // We reuse dart:convert's JsonEncoder (with indentation) rather than a
    // YAML writer because JSON is a strict subset of YAML syntax - any
    // valid indented JSON is valid YAML, and loadYaml() above can read it
    // straight back in.
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}
