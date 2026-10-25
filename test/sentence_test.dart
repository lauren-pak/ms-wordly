import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/data/word_bank.dart';
import 'package:ms_wordly/models/word.dart';
import 'package:ms_wordly/services/answer_check.dart';
import 'package:ms_wordly/services/sentence_challenges.dart';
import 'package:ms_wordly/services/sentence_grader.dart';
import 'package:ms_wordly/widgets/exercises.dart';

class FakeGrader implements SentenceGrader {
  FakeGrader(this.result);
  final GradeResult? result;
  int calls = 0;

  @override
  Future<GradeResult> grade(Word w, SentenceChallenge c, String s) async {
    calls++;
    final r = result;
    if (r == null) throw GradeException("Couldn't reach Claude.");
    return r;
  }
}

SentenceChallenge challenge(Word w, String id) =>
    challengesFor(w).firstWhere((c) => c.id == id);

void main() {
  final mitigate = wordsById['mitigate']!;

  group('challenges', () {
    test('checks enforce the constraint', () {
      String? check(String id, String s) => challenge(mitigate, id).check!(s);
      expect(check('question', 'Can we mitigate the risk'), isNotNull);
      expect(check('question', 'Can we mitigate the risk?'), isNull);
      expect(check('negative', 'We mitigated the risk.'), isNotNull);
      expect(check('negative', "We didn't mitigate the risk."), isNull);
      expect(check('past', 'We will mitigate the risk.'), isNotNull);
      expect(check('past', 'We mitigated the risk.'), isNull);
      expect(check('future', 'We will mitigate the risk.'), isNull);
      expect(check('opinion', 'I think we can mitigate it.'), isNull);
      expect(check('form:mitigation', 'We need to mitigate it.'), isNotNull);
      expect(check('form:mitigation', 'Risk mitigation matters.'), isNull);
    });

    test('alternate spellings are not form challenges', () {
      final ids = challengesFor(wordsById['prioritize']!).map((c) => c.id);
      expect(ids, contains('form:prioritized'));
      expect(ids, isNot(contains('form:prioritise')));
    });

    test('picks challenges not done yet, then cycles', () {
      final all = challengesFor(mitigate).map((c) => c.id).toList();
      final rng = Random(1);
      final done = <String>[];
      for (var i = 0; i < all.length; i++) {
        done.add(pickChallenge(mitigate, done, random: rng).id);
      }
      expect(done.toSet(), all.toSet());
      expect(all, contains(pickChallenge(mitigate, done, random: rng).id));
    });
  });

  test('similar sentences are caught', () {
    expect(
      tooSimilarTo('We added tests to mitigate the risk.', [
        'We added more tests to mitigate the risk.',
      ]),
      isNotNull,
    );
    expect(
      tooSimilarTo('Sleep helps mitigate stress after work.', [
        'We added more tests to mitigate the risk.',
      ]),
      isNull,
    );
  });

  group('SentenceStepView', () {
    Future<List<Object?>> pump(
      WidgetTester tester, {
      required String challengeId,
      SentenceGrader? grader,
      List<String> earlier = const [],
    }) async {
      final answers = <Object?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SentenceStepView(
              word: mitigate,
              challenge: challenge(mitigate, challengeId),
              earlierSentences: earlier,
              grader: grader,
              onAnswered: (passed, {sentence, challengeId}) =>
                  answers.addAll([passed, sentence, challengeId]),
            ),
          ),
        ),
      );
      return answers;
    }

    Future<void> write(WidgetTester tester, String s) async {
      await tester.enterText(find.byType(TextField), s);
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();
    }

    testWidgets('rejects repeats and unmet challenges', (tester) async {
      await pump(
        tester,
        challengeId: 'question',
        earlier: ['Exercise can mitigate stress for most people?'],
      );
      await write(tester, 'Exercise can mitigate stress for most people?');
      expect(find.textContaining('already wrote'), findsOneWidget);
      await write(tester, 'Breathing slowly will mitigate my nerves.');
      expect(find.textContaining('Make it a question'), findsOneWidget);
    });

    testWidgets('self-check without a key', (tester) async {
      final answers = await pump(tester, challengeId: 'text');
      await write(tester, 'lol coffee might mitigate my monday mood');
      await tester.tap(find.text('Yes, it fits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      expect(answers, [
        true,
        'lol coffee might mitigate my monday mood',
        'text',
      ]);
    });

    testWidgets('Claude marks misuse as a miss', (tester) async {
      final grader = FakeGrader(
        const GradeResult(
          UsageVerdict.incorrect,
          'Mitigate means to lessen harm, not to argue.',
          'We tried to mitigate the damage from the storm.',
        ),
      );
      final answers = await pump(tester, challengeId: 'work', grader: grader);
      await write(tester, 'Please mitigate with the client about pricing.');
      expect(grader.calls, 1);
      expect(find.textContaining('lessen harm'), findsOneWidget);
      expect(find.textContaining('Better:'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(answers, [false, null, null]);
    });

    testWidgets('falls back to self-check if Claude fails', (tester) async {
      await pump(tester, challengeId: 'work', grader: FakeGrader(null));
      await write(tester, 'We should mitigate the delay with a clear update.');
      expect(find.text('Yes, it fits'), findsOneWidget);
      expect(find.textContaining("Couldn't reach"), findsOneWidget);
    });
  });
}
