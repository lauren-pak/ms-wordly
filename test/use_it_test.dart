import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/data/scenarios.dart';
import 'package:ms_wordly/data/word_bank.dart';
import 'package:ms_wordly/models/word.dart';
import 'package:ms_wordly/screens/use_it_test_screen.dart';
import 'package:ms_wordly/services/progress_store.dart';
import 'package:ms_wordly/services/sentence_grader.dart';
import 'package:ms_wordly/services/use_it_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeResponseGrader implements ResponseGrader {
  final calls = <List<String>>[];

  @override
  Future<ResponseGrade> gradeResponse(
    String scenario,
    String response,
    List<Word> words,
  ) async {
    calls.add(words.map((w) => w.word).toList());
    return ResponseGrade(
      [
        for (final w in words)
          WordGrade(
            w,
            w.word == 'concise' ? UsageVerdict.incorrect : UsageVerdict.correct,
            'Feedback on ${w.word}.',
          ),
      ],
      'Sounds natural.',
      response,
    );
  }
}

void main() {
  final candid = wordsById['candid']!;
  final concise = wordsById['concise']!;
  final convey = wordsById['convey']!;

  test('spots learned words in any form', () {
    final text = 'I was candid with her. It conveyed how I felt.';
    expect(wordsUsedIn(text, [candid, concise, convey]), [candid, convey]);
    expect(sentenceWith(text, convey), 'It conveyed how I felt.');
  });

  test('scenarios never name a word from the bank', () {
    for (final s in scenarios) {
      expect(wordsUsedIn(s, wordBank), isEmpty, reason: s);
    }
  });

  Future<ProgressStore> storeWith(List<Word> words) async {
    SharedPreferences.setMockInitialValues({});
    final s = ProgressStore(
      await SharedPreferences.getInstance(),
      clock: () => DateTime(2026, 10, 25, 9),
    );
    for (final w in words) {
      s.progress[w.id] = WordProgress(
        id: w.id,
        learnedOn: '2026-10-20',
        due: '2026-11-20',
      );
    }
    return s;
  }

  test('a misused word comes back tomorrow and sentences are kept', () async {
    final s = await storeWith([candid, concise]);
    await s.completeUseItTest(
      results: {'candid': true, 'concise': false},
      sentences: {
        'candid': ['I was candid.'],
      },
    );
    expect(s.progress['concise']!.due, '2026-10-26');
    expect(s.progress['candid']!.due, '2026-11-20');
    expect(s.progress['candid']!.sentences, ['I was candid.']);
    expect(s.unlocked, contains('use_it_1'));
  });

  Future<void> reply(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('needs two learned words, then Claude checks each', (
    tester,
  ) async {
    final store = await storeWith([candid, concise, convey]);
    final grader = FakeResponseGrader();
    await tester.pumpWidget(
      MaterialApp(
        home: UseItTestScreen(store: store, grader: grader),
      ),
    );
    Finder check() => find.widgetWithText(FilledButton, 'Check');

    await reply(tester, 'I will be candid.');
    expect(tester.widget<FilledButton>(check()).onPressed, isNull);

    for (var round = 0; round < 3; round++) {
      await reply(tester, 'To be candid, keep it concise.');
      expect(find.text('Spotted:'), findsOneWidget);
      await tester.tap(check());
      await tester.pumpAndSettle();
      expect(find.text('Feedback on candid.'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(grader.calls, hasLength(3));
    expect(find.text('1 word used well'), findsOneWidget);
    expect(store.useItTests, 1);
    expect(store.progress['concise']!.due, '2026-10-26');
  });

  testWidgets('without a key, the user checks their own words', (tester) async {
    final store = await storeWith([candid, concise, convey]);
    await tester.pumpWidget(MaterialApp(home: UseItTestScreen(store: store)));
    expect(find.text('Turn on AI checking'), findsOneWidget);
    await reply(tester, 'I was candid and it conveyed respect.');
    await tester.tap(find.widgetWithText(FilledButton, 'Check'));
    await tester.pumpAndSettle();
    final cont = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(cont).onPressed, isNull);
    await tester.tap(find.text('Used it right').first);
    await tester.ensureVisible(find.text('Used it right').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Used it right').last);
    await tester.pump();
    expect(tester.widget<FilledButton>(cont).onPressed, isNotNull);
  });
}
