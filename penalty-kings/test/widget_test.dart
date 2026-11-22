import 'package:flutter_test/flutter_test.dart';
import 'package:penalty_kings/main.dart';

void main() {
  testWidgets('Penalty Kings app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const PenaltyKingsApp());
    expect(find.text('Penalty Kings'), findsOneWidget);
  });
}
