import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart' as yaml;

import '../models/category.dart';
import 'settings_service.dart';

// Which "kind" of template a TemplateFile is - used to sort bundled files
// into the right section of the UI (ingredient pickers vs. recipe pickers).
enum TemplateType { ingredient, recipe }

// A lightweight reference to a template file: just enough info (path, a
// human-friendly name, and its type) to show it in a list before the user
// has chosen to actually open/read it. Reading the full content only
// happens later, via loadTemplateCategories() below.
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

// ============================================================================
// TemplateService
// ----------------------------------------------------------------------------
// Reads (and writes) the template YAML files that back both the "Zarządzaj
// zestawami" (manage homebars) screens AND, via
// resolveActiveIngredientTemplate(), the user's actual live inventory -
// there's no separate "inventory" storage anymore, it's simply whichever
// ingredient template is currently selected (or the bundled default, if
// none has been). Templates are parsed into the same Category/Ingredient
// models used everywhere else in the app (see lib/models/), so any editing
// logic only has to exist once.
//
// Every template ultimately lives as a real file in one of two places:
//   - Bundled under assets/data/ - ships inside the app package, read-only
//     at runtime. Discovered via the asset manifest (loadBundledTemplates).
//   - In the app's documents directory, under a "templates" folder - both
//     brand-new templates created via createIngredientTemplate(), and
//     writable *copies* of bundled templates once they've been edited
//     (since the bundled originals can't be written to). See
//     _templatesDirectory/_editableCopyFor.
// ============================================================================
class TemplateService {
  // Folders that are scanned for template files, paired with the
  // TemplateType every .yaml file found inside them should be tagged with.
  // Add a new folder here (and to the `assets:` list in pubspec.yaml) to
  // support a new template category.
  static const _templateFolders = {
    'assets/data/ingredient/': TemplateType.ingredient,
    'assets/data/recipe/': TemplateType.recipe,
  };

  // The ingredient template used when nothing has been explicitly selected
  // yet (see resolveActiveIngredientTemplate) - the same bundled file the
  // app has always shipped with.
  static const defaultIngredientTemplate = TemplateFile(
    path: 'assets/data/ingredient/ingredients.yaml',
    name: 'Szablon składników',
    type: TemplateType.ingredient,
  );

  // Figures out which ingredient template is "active" right now - i.e.
  // which one screens like CategoryBrowserScreen should load and save
  // against. That's whichever template is selected in "Zarządzaj
  // zestawami" (see SettingsService), or defaultIngredientTemplate if
  // nothing has been selected yet (first run) or the previously selected
  // template can no longer be found (e.g. its file was removed outside
  // the app).
  static Future<TemplateFile> resolveActiveIngredientTemplate() async {
    // Older versions of the app stored the user's inventory in a
    // completely separate file, outside this template system - bring that
    // data along the first time it's needed under the new, unified scheme.
    await _migrateLegacyInventoryFileIfNeeded();

    final settings = await SettingsService.load();
    final selectedPath = settings.selectedIngredientTemplatePath;
    if (selectedPath == null) return defaultIngredientTemplate;

    final templates = await loadBundledTemplates();
    return templates.firstWhere(
      (t) => t.type == TemplateType.ingredient && t.path == selectedPath,
      orElse: () => defaultIngredientTemplate,
    );
  }

  // Earlier versions of the app stored the user's ingredient inventory
  // directly at <documents>/ingredients.yaml (via a now-removed
  // FileHandler service), instead of going through the same per-template
  // writable-copy scheme every other template uses. If that legacy file is
  // still there and hasn't been migrated yet, copy it into place so
  // existing data isn't silently dropped the first time this app version
  // runs.
  static Future<void> _migrateLegacyInventoryFileIfNeeded() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final legacyFile = File('${documentsDir.path}/ingredients.yaml');
    if (!await legacyFile.exists()) return;

    final newFile = await _editableCopyFor(defaultIngredientTemplate);
    if (await newFile.exists()) return;

    await newFile.parent.create(recursive: true);
    await legacyFile.copy(newFile.path);
  }

  // Discovers every template file - both bundled ones (read from Flutter's
  // asset manifest, since there's no plain directory-listing API for
  // bundled assets) and any the user has created themselves (read from the
  // real "templates" folder in the documents directory).
  static Future<List<TemplateFile>> loadBundledTemplates() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assetPaths = manifest.listAssets();

    final templates = <TemplateFile>[];
    // Tracks which filenames are already accounted for by a bundled asset,
    // so the documents-folder scan below doesn't list the *writable copy*
    // of an edited bundled template as if it were a second, separate one.
    final bundledFileNames = <String>{};

    for (final entry in _templateFolders.entries) {
      final folder = entry.key;
      final type = entry.value;

      final matches = assetPaths
          .where((path) => path.startsWith(folder) && path.endsWith('.yaml'))
          .toList()
        // Sort for a stable, predictable order in the picker UI.
        ..sort();

      for (final path in matches) {
        templates.add(
          TemplateFile(
            path: path,
            name: _labelFor(path, type),
            type: type,
          ),
        );
        bundledFileNames.add(_fileNameOf(path));
      }
    }

    // User-created templates (via "Dodaj nowy zestaw") live only in the
    // documents directory - there's no bundled asset to discover them
    // from, so the folder has to be listed directly.
    final templatesDir = await _templatesDirectory();
    if (await templatesDir.exists()) {
      final userFiles = templatesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .where((f) => !bundledFileNames.contains(_fileNameOf(f.path)))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in userFiles) {
        // Every template created through this app today is an ingredient
        // set - see createIngredientTemplate() below.
        const type = TemplateType.ingredient;
        templates.add(
          TemplateFile(
            path: file.path,
            name: await _displayNameFor(file) ?? _labelFor(file.path, type),
            type: type,
          ),
        );
      }
    }

    return templates;
  }

  // Builds a human-friendly display name from a file path, e.g.
  // ".../ingredients.yaml" -> "Szablon składników" and
  // ".../ingredients_2.yaml" -> "Szablon składników 2", so multiple
  // template files of the same type stay distinguishable in the UI. Used
  // as a fallback for files that don't carry an explicit `template_name`
  // (see _displayNameFor) - i.e. every bundled template.
  static String _labelFor(String path, TemplateType type) {
    final baseLabel = type == TemplateType.ingredient
        ? 'Szablon składników'
        : 'Szablon przepisów';

    final fileName = _fileNameOf(path).replaceAll('.yaml', '');
    final suffixMatch = RegExp(r'[_-](\w+)$').firstMatch(fileName);
    if (suffixMatch == null) return baseLabel;

    return '$baseLabel ${suffixMatch.group(1)}';
  }

  // Reads a file's own `template_name` field, if it has one (see
  // saveTemplateCategories - every save stamps the template's current
  // display name into the file), so a user-typed name like "Wesele u Ani"
  // survives being displayed later instead of being reconstructed - badly
  // - from its filename.
  static Future<String?> _displayNameFor(File file) async {
    try {
      final content = await file.readAsString();
      final data = yaml.loadYaml(content);
      if (data is Map && data['template_name'] is String) {
        return data['template_name'] as String;
      }
    } catch (_) {
      // Fall through to null - the caller falls back to _labelFor().
    }
    return null;
  }

  // The folder (inside the app's documents directory) that holds both
  // user-created templates and writable copies of edited bundled ones.
  static Future<Directory> _templatesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    return Directory('${directory.path}/templates');
  }

  // Resolves the writable, per-template file that edits are read from and
  // written to. Keyed by filename only (not the full original path), so a
  // template keeps the same writable copy across app runs regardless of
  // which asset folder it originally came from. For a template that's
  // already a real file in the documents directory (i.e. anything created
  // via createIngredientTemplate()), this simply resolves back to that
  // same file.
  static Future<File> _editableCopyFor(TemplateFile template) async {
    final directory = await _templatesDirectory();
    return File('${directory.path}/${_fileNameOf(template.path)}');
  }

  // Loads a template's content as an editable Category tree. Prefers the
  // writable copy if edits have ever been saved for this template;
  // otherwise falls back to the original read-only bundled asset.
  static Future<List<Category>> loadTemplateCategories(TemplateFile template) async {
    final editableCopy = await _editableCopyFor(template);

    final content = await editableCopy.exists()
        ? await editableCopy.readAsString()
        : await _loadOptionalText(template.path);

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
        .map((item) => Category.fromYaml(Map<String, dynamic>.from(item)))
        .toList();
  }

  // Persists edits to a template by writing its writable copy, creating
  // the containing folder on first use. Never touches the original
  // bundled asset (which is read-only at runtime anyway). Always stamps
  // the template's current display name into the file as `template_name`,
  // so a user-created template's real name survives round-tripping
  // through further edits (see _displayNameFor).
  static Future<void> saveTemplateCategories(
    TemplateFile template,
    List<Category> categories,
  ) async {
    final file = await _editableCopyFor(template);
    await file.parent.create(recursive: true);

    final data = {
      'template_name': template.name,
      'categories': categories.map((e) => e.toYaml()).toList(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  // Reads a text file from either the bundled asset bundle (paths starting
  // with "assets/") or the real filesystem, returning null instead of
  // throwing when the file is missing or unreadable.
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

  // Creates a brand-new ingredient template from scratch: a real file in
  // the documents directory, seeded with the given top-level category
  // names (no subcategories or ingredients yet - those get added
  // afterwards through the normal template editor).
  static Future<TemplateFile> createIngredientTemplate({
    required String name,
    required List<String> categoryNames,
  }) async {
    final directory = await _templatesDirectory();
    await directory.create(recursive: true);

    final file = await _uniqueFileFor(directory, name);
    final template = TemplateFile(path: file.path, name: name, type: TemplateType.ingredient);
    final categories = categoryNames.map((n) => Category(name: n)).toList();

    // Reuses the normal save path, so this new file ends up in exactly the
    // shape (including the `template_name` field) every other write to a
    // template produces.
    await saveTemplateCategories(template, categories);

    return template;
  }

  // Picks a filesystem-safe filename for a new template, derived from its
  // display name (e.g. "Wesele u Ani" -> "wesele_u_ani.yaml"), appending a
  // numeric suffix if that name is already taken by another file.
  static Future<File> _uniqueFileFor(Directory directory, String name) async {
    final slug = _slugify(name);

    var candidate = File('${directory.path}/$slug.yaml');
    var suffix = 2;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/${slug}_$suffix.yaml');
      suffix++;
    }
    return candidate;
  }

  static String _slugify(String name) {
    final lower = name.trim().toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return cleaned.isEmpty ? 'zestaw' : cleaned;
  }

  // Strips a path down to just its filename, tolerating both `/` (asset
  // paths, always forward-slash) and `\` (native Windows paths, e.g. from
  // Directory.listSync()) as separators.
  static String _fileNameOf(String path) => path.replaceAll('\\', '/').split('/').last;
}
