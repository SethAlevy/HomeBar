import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart' as yaml;
import '../models/category.dart';

class FileHandler {
  static const String _fileName = 'ingredients.yaml';

  // Get the path to the YAML file in the app's documents directory
  static Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  // Load data from YAML file
  static Future<List<Category>> loadCategories() async {
    try {
      final file = File(await _getFilePath());
      if (!await file.exists()) {
        // If file doesn't exist, create it with default content
        await _createDefaultFile();
        return [];
      }
      final content = await file.readAsString();
      final root = yaml.loadYaml(content);
      if (root is! Map) return [];

      final yamlData = Map<String, dynamic>.from(root);

      final categoriesData = yamlData['categories'];
      if (categoriesData is! List) return [];

      return categoriesData
          .map((e) => Category.fromYaml(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Save categories to YAML file
  static Future<void> saveCategories(List<Category> categories) async {
    final file = File(await _getFilePath());
    final yamlData = {'categories': categories.map((e) => e.toYaml()).toList()};
    final yamlString = const JsonEncoder.withIndent('  ').convert(yamlData);
    await file.writeAsString(yamlString);
  }

  // Create default YAML file if it doesn't exist
  static Future<void> _createDefaultFile() async {
    final file = File(await _getFilePath());
    const defaultContent = '''
categories:
  - name: "Alcoholic"
    subcategories:
      - name: "Strong Alcohol"
        subcategories:
          - name: "Rum"
            ingredients: []
          - name: "Whiskey"
            ingredients: []
      - name: "Liqueurs"
        subcategories: []
        ingredients: []
  - name: "Non-Alcoholic"
    subcategories:
      - name: "Juices"
        subcategories: []
        ingredients: []
      - name: "Soda"
        subcategories: []
        ingredients: []
  - name: "Home Products"
    subcategories:
      - name: "Herbs"
        subcategories: []
        ingredients: []
''';
    await file.writeAsString(defaultContent);
  }
}
