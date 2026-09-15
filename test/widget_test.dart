import 'package:flutter_test/flutter_test.dart';
import 'package:practicepal/main.dart';

void main() {
  testWidgets('PracticePalApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PracticePalApp());
    await tester.pumpAndSettle();

    // Verify header renders
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Pal'), findsOneWidget);
    expect(find.text("I'm a Trainer"), findsOneWidget);
    expect(find.text("I'm a Student"), findsOneWidget);
  });
}
