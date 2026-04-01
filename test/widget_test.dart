import 'package:flutter_test/flutter_test.dart';
import 'package:inspection_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: InspectionApp()),
    );
    expect(find.byType(InspectionApp), findsOneWidget);
  });
}