import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

// A snapshot of the app's small set of persisted preferences. Currently
// just "which templates are selected" - see SettingsService below for how
// this gets read from/written to disk.
class AppSettings {
  final String? selectedIngredientTemplatePath;
  final String? selectedRecipeTemplatePath;

  const AppSettings({
    this.selectedIngredientTemplatePath,
    this.selectedRecipeTemplatePath,
  });

  // What a fresh install (or a corrupt/missing settings file) starts from -
  // nothing selected yet.
  static const empty = AppSettings();

  Map<String, dynamic> toJson() => {
        'selectedIngredientTemplatePath': selectedIngredientTemplatePath,
        'selectedRecipeTemplatePath': selectedRecipeTemplatePath,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        selectedIngredientTemplatePath: json['selectedIngredientTemplatePath'] as String?,
        selectedRecipeTemplatePath: json['selectedRecipeTemplatePath'] as String?,
      );
}

// ============================================================================
// SettingsService
// ----------------------------------------------------------------------------
// Persists small, app-wide preferences - right now just which ingredient
// and recipe template are "active" - to a plain JSON file in the app's
// documents directory. Same "writable file in the documents folder"
// approach TemplateService already uses for template data, so there's no
// need for a whole new storage dependency just for a couple of settings.
// ============================================================================
class SettingsService {
  static const _fileName = 'settings.json';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  // Reads the persisted settings, or AppSettings.empty if none have ever
  // been saved (e.g. first run) or the file can't be parsed.
  static Future<AppSettings> load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return AppSettings.empty;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return AppSettings.empty;

      return AppSettings.fromJson(jsonDecode(content) as Map<String, dynamic>);
    } catch (_) {
      // Any read/parse failure (corrupt file, unexpected format after a
      // future format change, etc.) falls back to "nothing selected"
      // rather than crashing whichever screen asked for settings.
      return AppSettings.empty;
    }
  }

  // Overwrites the persisted "selected templates". Both parameters are
  // independently nullable so a caller can save "nothing selected" for
  // either one without needing to already know the other's current value.
  static Future<void> saveSelectedTemplates({
    String? ingredientTemplatePath,
    String? recipeTemplatePath,
  }) async {
    final file = await _getFile();
    final settings = AppSettings(
      selectedIngredientTemplatePath: ingredientTemplatePath,
      selectedRecipeTemplatePath: recipeTemplatePath,
    );
    await file.writeAsString(jsonEncode(settings.toJson()));
  }
}
