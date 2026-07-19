import 'package:flutter_test/flutter_test.dart';

import 'package:homebar/main.dart';

void main() {
  testWidgets('HomeBar app renders title', (WidgetTester tester) async {
    await tester.pumpWidget(const HomeBarApp());
    expect(find.text('HomeBar'), findsOneWidget);
  });
}
