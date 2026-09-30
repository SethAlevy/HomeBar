import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homebar/widgets/editable_chip_list.dart';

void main() {
  Widget buildChipList({
    required List<String> items,
    required List<String> suggestions,
    required TextEditingController controller,
    required VoidCallback onAdd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: EditableChipList(
          items: items,
          onRemove: (_) {},
          newItemController: controller,
          onAdd: onAdd,
          addFieldLabel: 'Nowy tag',
          suggestions: suggestions,
        ),
      ),
    );
  }

  testWidgets('shows a matching existing tag as an autocomplete option', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['bourbon', 'gin', 'wermut wytrawny'],
        controller: controller,
        onAdd: () {},
      ),
    );

    await tester.enterText(find.byType(TextField), 'bour');
    await tester.pumpAndSettle();

    expect(find.text('bourbon'), findsOneWidget);
  });

  testWidgets('selecting an autocomplete option fills the field and adds it', (tester) async {
    final controller = TextEditingController();
    var added = false;
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['bourbon', 'gin'],
        controller: controller,
        onAdd: () => added = true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'bour');
    await tester.pumpAndSettle();

    await tester.tap(find.text('bourbon'));
    await tester.pumpAndSettle();

    expect(controller.text, 'bourbon');
    expect(added, isTrue);
  });

  testWidgets('tapping "+" on a likely typo opens a confirmation dialog', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['bourbon'],
        controller: controller,
        onAdd: () {},
      ),
    );

    await tester.enterText(find.byType(TextField), 'bourban');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj'));
    await tester.pumpAndSettle();

    expect(find.text('Czy chodziło Ci o...?'), findsOneWidget);
    expect(find.text('Wpisano "bourban". Czy chodziło Ci o "bourbon"?'), findsOneWidget);
  });

  testWidgets('choosing the suggested spelling in the dialog uses it instead', (tester) async {
    final controller = TextEditingController();
    var added = false;
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['bourbon'],
        controller: controller,
        onAdd: () => added = true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'bourban');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Użyj "bourbon"'));
    await tester.pumpAndSettle();

    expect(controller.text, 'bourbon');
    expect(added, isTrue);
  });

  testWidgets('choosing to keep the typed text in the dialog leaves it as-is', (tester) async {
    final controller = TextEditingController();
    var added = false;
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['bourbon'],
        controller: controller,
        onAdd: () => added = true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'bourban');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zachowaj "bourban"'));
    await tester.pumpAndSettle();

    expect(controller.text, 'bourban');
    expect(added, isTrue);
  });

  testWidgets('does not open the typo dialog for a tag already added', (tester) async {
    final controller = TextEditingController();
    var added = false;
    await tester.pumpWidget(
      buildChipList(
        items: const ['bourbon'],
        suggestions: const ['bourbon'],
        controller: controller,
        onAdd: () => added = true,
      ),
    );

    await tester.enterText(find.byType(TextField), 'bourban');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj'));
    await tester.pumpAndSettle();

    expect(find.text('Czy chodziło Ci o...?'), findsNothing);
    expect(added, isTrue);
  });

  testWidgets('recognizes a tag typed without its Polish diacritics as a typo', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      buildChipList(
        items: const [],
        suggestions: const ['pomarańczowy'],
        controller: controller,
        onAdd: () {},
      ),
    );

    await tester.enterText(find.byType(TextField), 'pomaranczowy');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dodaj'));
    await tester.pumpAndSettle();

    expect(find.text('Wpisano "pomaranczowy". Czy chodziło Ci o "pomarańczowy"?'), findsOneWidget);
  });
}
