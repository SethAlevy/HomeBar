import 'package:flutter_test/flutter_test.dart';
import 'package:homebar/services/template_service.dart';

void main() {
  testWidgets('loadRecipes parses the bundled recipe.yaml', (tester) async {
    final recipes = await TemplateService.loadRecipes(TemplateService.defaultRecipeTemplate);

    expect(recipes.length, 2);

    final margarita = recipes.firstWhere((r) => r.name == 'Margarita');
    // ignore: avoid_print
    print('Margarita ingredients: ${margarita.ingredients.map((i) => '${i.name}|${i.amount}')}');
    // ignore: avoid_print
    print('Margarita instructions: "${margarita.instructions}"');
    // ignore: avoid_print
    print('Margarita tags: ${margarita.tags}');

    expect(margarita.ingredients.length, 3);
    expect(margarita.ingredients.first.name, 'Tequila');
    expect(margarita.ingredients.first.amount, '1 porcja');
    expect(margarita.instructions, contains('Umieść wszystkie składniki'));
    expect(margarita.tags, contains('tequila'));
  });
}
