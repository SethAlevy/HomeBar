import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart' as yaml;

import '../models/category.dart';

class FileHandler {
  static const _fileName = 'ingredients.yaml';

  static Future<File> _getFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  static Future<List<Category>> loadCategories() async {
    try {
      final file = await _getFile();

      if (!await file.exists()) {
        final defaultContent = await rootBundle.loadString(
          'assets/data/ingredients.yaml',
        );
        await file.writeAsString(defaultContent);
      }

      final content = await file.readAsString();
      final data = yaml.loadYaml(content);

      if (data is! Map || data['categories'] is! List) {
        return [];
      }

      return (data['categories'] as List)
          .map((category) => Category.fromYaml(
                Map<String, dynamic>.from(category as Map),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCategories(List<Category> categories) async {
    final file = await _getFile();
    final data = {'categories': categories.map((e) => e.toYaml()).toList()};
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
}
