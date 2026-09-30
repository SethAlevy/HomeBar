import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homebar/widgets/editable_chip_list.dart';

void main() {
  testWidgets('autocomplete options show inside a showDialog AlertDialog', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: SizedBox(
                      width: 400,
                      child: SingleChildScrollView(
                        child: EditableChipList(
                          items: const [],
                          onRemove: (_) {},
                          newItemController: controller,
                          onAdd: () {},
                          addFieldLabel: 'Nowy tag',
                          suggestions: const ['whisky', 'wermut'],
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'wh');
    await tester.pumpAndSettle();

    expect(find.text('whisky'), findsOneWidget);
  });
}
