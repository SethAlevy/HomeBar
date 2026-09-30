import 'package:flutter_test/flutter_test.dart';

import 'package:homebar/models/category.dart';
import 'package:homebar/models/ingredient.dart';

Ingredient _ingredient(String name, List<String> tags) => Ingredient(
      name: name,
      producer: '',
      description: '',
      bottlesCount: 1,
      tags: tags,
    );

void main() {
  group('suggestTagsForNewIngredient', () {
    test('suggests a tag shared by at least 2 existing ingredients', () {
      final category = Category(
        name: 'Mocne',
        ingredients: [
          _ingredient('Bacardi Jasny', ['rum', 'baza']),
          _ingredient('Johnnie Walker', ['whisky', 'baza']),
        ],
      );

      expect(suggestTagsForNewIngredient(category), contains('baza'));
    });

    test('does not suggest a tag used by only 1 existing ingredient', () {
      final category = Category(
        name: 'Mocne',
        ingredients: [
          _ingredient('Bacardi Jasny', ['rum', 'karaibski']),
          _ingredient('Johnnie Walker', ['whisky']),
        ],
      );

      expect(suggestTagsForNewIngredient(category), isNot(contains('karaibski')));
    });

    test('counts ingredients from subcategories too', () {
      final category = Category(
        name: 'Mocne',
        subcategories: [
          Category(name: 'Rum', ingredients: [_ingredient('Bacardi Jasny', ['baza'])]),
          Category(name: 'Whisky', ingredients: [_ingredient('Johnnie Walker', ['baza'])]),
        ],
      );

      expect(suggestTagsForNewIngredient(category), contains('baza'));
    });

    test('suggests nothing for an empty category', () {
      final category = Category(name: 'Nowa kategoria');

      expect(suggestTagsForNewIngredient(category), isEmpty);
    });
  });
}
