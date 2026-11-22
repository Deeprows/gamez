import 'package:flutter_test/flutter_test.dart';
import 'package:penalty_kings/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('Penalty Kings app starts on the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PenaltyKingsApp());
    await tester.pump();
    expect(find.byType(PenaltyKingsApp), findsOneWidget);
    expect(find.text('PENALTY KINGS'), findsOneWidget);
  });
}
