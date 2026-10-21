import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/main.dart';
import 'package:ms_wordly/services/progress_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('can play through a full first session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = ProgressStore(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 10, 21, 9),
    );
    await tester.pumpWidget(MsWordlyApp(store: store));
    expect(find.text("Today's words"), findsOneWidget);

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    // Give up on every typed exercise so retries are exercised too.
    for (var i = 0; i < 120; i++) {
      if (find.text('1 day streak').evaluate().isNotEmpty) break;
      if (find.text('Got it').evaluate().isNotEmpty) {
        await tester.tap(find.text('Got it'));
      } else if (find.text('Continue').evaluate().isNotEmpty) {
        await tester.tap(find.text('Continue'));
      } else if (find.text("I don't know").evaluate().isNotEmpty) {
        await tester.tap(find.text("I don't know"));
      } else if (find.text("I'm stuck").evaluate().isNotEmpty) {
        await tester.tap(find.text("I'm stuck"));
      } else {
        await tester.tap(find.byType(OutlinedButton).first);
      }
      await tester.pumpAndSettle();
    }

    expect(find.text('1 day streak'), findsOneWidget);
    expect(store.progress, hasLength(3));
    await tester.scrollUntilVisible(find.text('Back home'), 200);
    await tester.tap(find.text('Back home'));
    await tester.pumpAndSettle();
    expect(find.text('Done for today'), findsOneWidget);
    await tester.tap(find.text('I used it').first);
    await tester.pumpAndSettle();
    expect(store.usedInLifeCount, 1);
  });
}
