import 'package:flutter_test/flutter_test.dart';

import 'dart:math';

import 'package:ms_wordly/models/word.dart';
import 'package:ms_wordly/services/progress_store.dart';
import 'package:ms_wordly/services/session_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance(), clock: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 21, 9);
  });

  Future<void> finishDay(ProgressStore s, {bool allRight = true}) =>
      s.completeSession(
        newWordResults: {for (final w in s.todaysNewWords) w.id: allRight},
        reviewResults: {for (final r in s.dueReviews) r.id: allRight},
      );

  test('three new words a day, stable within the day', () async {
    final s = await open();
    final first = s.todaysNewWords.map((w) => w.id).toList();
    expect(first, hasLength(wordsPerDay));
    expect(s.todaysNewWords.map((w) => w.id), first);
    await finishDay(s);
    now = now.add(const Duration(days: 1));
    expect(s.todaysNewWords.map((w) => w.id), isNot(contains(first.first)));
  });

  test('streak grows on consecutive days and resets after a gap', () async {
    final s = await open();
    await finishDay(s);
    expect(s.currentStreak, 1);
    await finishDay(s); // same day twice does not double count
    expect(s.currentStreak, 1);
    now = now.add(const Duration(days: 1));
    await finishDay(s);
    expect(s.currentStreak, 2);
    now = now.add(const Duration(days: 2));
    expect(s.currentStreak, 0);
    await finishDay(s);
    expect(s.currentStreak, 1);
    expect(s.bestStreak, 2);
  });

  test('reviews space out when right and come back when wrong', () async {
    final s = await open();
    await finishDay(s);
    final id = s.todaysNewWords.first.id;
    expect(s.progress[id]!.due, '2026-10-22');

    now = DateTime(2026, 10, 22, 9);
    expect(s.dueReviews.map((r) => r.id), contains(id));
    await finishDay(s);
    expect(s.progress[id]!.level, 2);
    expect(s.progress[id]!.due, '2026-10-25');

    now = DateTime(2026, 10, 25, 9);
    await s.completeSession(newWordResults: {}, reviewResults: {id: false});
    expect(s.progress[id]!.level, 1);
    expect(s.progress[id]!.due, '2026-10-26');
  });

  test('state survives a restart', () async {
    final s = await open();
    await s.completeSession(
      newWordResults: {for (final w in s.todaysNewWords) w.id: true},
      reviewResults: {},
      sentences: {
        s.todaysNewWords.first.id: ['I articulate it well today.'],
      },
    );
    await s.markUsedInLife(s.todaysNewWords.first.id);
    final again = await open();
    expect(again.progress, hasLength(3));
    expect(again.currentStreak, 1);
    expect(again.usedInLifeCount, 1);
    expect(again.progress[s.todaysNewWords.first.id]!.sentences, hasLength(1));
  });

  test('session covers every new word with each exercise type', () async {
    final s = await open();
    final steps = buildSession(s.todaysNewWords, []);
    for (final kind in [
      StepKind.learn,
      StepKind.choose,
      StepKind.cloze,
      StepKind.recall,
      StepKind.sentence,
    ]) {
      expect(steps.where((st) => st.kind == kind), hasLength(3));
    }
    final choose = steps.firstWhere((st) => st.kind == StepKind.choose);
    expect(choose.options, hasLength(4));
    expect(choose.options, contains(choose.word));
  });

  test('extra practice never pushes words out, misses come back', () async {
    final s = await open();
    await finishDay(s);
    final ids = s.todaysNewWords.map((w) => w.id).toList();
    now = DateTime(2026, 10, 22, 9);
    await finishDay(s); // levels to 2, due in 3 days
    await s.completePractice(results: {ids[0]: true, ids[1]: false});
    expect(s.progress[ids[0]]!.level, 2);
    expect(s.progress[ids[0]]!.due, '2026-10-25');
    expect(s.progress[ids[1]]!.due, '2026-10-23');
  });

  test('more words after the daily session skip today\'s plan', () async {
    final s = await open();
    final today = s.todaysNewWords.map((w) => w.id);
    final more = s.nextNewWords().map((w) => w.id);
    expect(more, hasLength(3));
    expect(more.toSet().intersection(today.toSet()), isEmpty);
    await finishDay(s);
    await s.completeSession(
      newWordResults: {for (final id in more) id: true},
      reviewResults: {},
      challenges: {
        more.first: ['question'],
      },
    );
    expect(s.learnedToday, hasLength(6));
    expect(s.currentStreak, 1);
    final again = await open();
    expect(again.progress[more.first]!.challengesDone, ['question']);
  });

  test('api key is stored and cleared', () async {
    final s = await open();
    expect(s.apiKey, isNull);
    await s.setApiKey('  sk-ant-test ');
    expect((await open()).apiKey, 'sk-ant-test');
    await s.setApiKey('');
    expect(s.apiKey, isNull);
  });

  test('new words follow the chosen difficulty', () async {
    final s = await open();
    expect(s.todaysNewWords.map((w) => w.difficulty).toSet(), {
      Difficulty.stretch,
    });
    await s.setDifficulty(Difficulty.advanced);
    expect(s.todaysNewWords.map((w) => w.difficulty).toSet(), {
      Difficulty.advanced,
    });
    await finishDay(s);
    await s.setDifficulty(Difficulty.everyday);
    expect(s.todaysNewWords.first.difficulty, Difficulty.advanced);
    expect(s.nextNewWords().first.difficulty, Difficulty.everyday);
    expect((await open()).difficulty, Difficulty.everyday);
  });

  test('practice avoids recent exercises and mixes in new kinds', () async {
    final s = await open();
    await s.completeSession(
      newWordResults: {for (final w in s.todaysNewWords) w.id: true},
      reviewResults: {},
      sentences: {
        'articulate': ['I could not articulate why the song made me cry.'],
      },
      exercises: {
        'articulate': ['cloze', 'recall', 'sentence'],
      },
    );
    final p = s.progress['articulate']!;
    final kinds = {for (var i = 0; i < 40; i++) pickExercise(p, Random(i)).key};
    expect(kinds, isNot(contains('cloze')));
    expect(kinds, isNot(contains('recall')));
    expect(kinds, containsAll(['swap:0', 'swap:1']));
    expect(kinds.any((k) => k.startsWith('own:')), isTrue);

    final own = exercisesFor(
      p,
      Random(1),
    ).firstWhere((e) => e.kind == StepKind.own);
    expect(own.ownSentence, contains('articulate'));

    for (var i = 0; i < 10; i++) {
      await s.completePractice(
        results: {'articulate': true},
        exercises: {
          'articulate': ['swap:0'],
        },
      );
    }
    expect(p.recentExercises, hasLength(recentLimit));

    final steps = buildPractice(
      [p],
      learned: s.progress.values.toList(),
      random: Random(2),
    );
    expect(steps.first.kind, isNot(StepKind.match)); // only 3 words learned
  });

  test('daily mission picks three learned words and pays out once', () async {
    final s = await open();
    expect(s.mission, isEmpty);
    await finishDay(s);
    final mission = s.mission.map((w) => w.id).toList();
    expect(mission, hasLength(missionSize));
    expect(s.mission.map((w) => w.id), mission); // stable within the day

    final before = s.points;
    await s.markUsedInLife(mission[0]);
    await s.markUsedInLife(mission[1]);
    expect(s.missionDone, isFalse);
    final reward = await s.markUsedInLife(mission[2]);
    expect(s.missionDone, isTrue);
    expect(s.missionsCompleted, 1);
    expect(reward!.unlocked.map((a) => a.id), contains('mission_1'));
    expect(s.points - before, greaterThan(3 * 2 + 15));
    expect(await s.markUsedInLife(mission[2]), isNull);

    // Next day: words just used wait while others get their turn.
    now = now.add(const Duration(days: 1));
    await finishDay(s);
    final next = s.mission.map((w) => w.id).toSet();
    expect(next.intersection(mission.toSet()), isEmpty);
    expect(s.missionDone, isFalse);

    final restored = await open();
    expect(restored.mission.map((w) => w.id).toSet(), next);
    expect(restored.missionsCompleted, 1);
  });

  test('recall test misses drop a level and come back tomorrow', () async {
    final s = await open();
    for (var i = 0; i < 4; i++) {
      await finishDay(s);
      now = now.add(const Duration(days: 1));
    }
    final words = s.testSet(random: Random(1));
    expect(words, hasLength(testSize));
    final hit = words[0], miss = words[1];
    miss.level = 3;
    miss.due = addDays(s.today, 10);
    await s.completeTest({hit.id: true, miss.id: false});
    expect(miss.level, 2);
    expect(miss.due, addDays(s.today, 1));
    expect(s.testsTaken, 1);
    expect(s.unlocked, contains('test_1'));

    await s.completeTest({for (final w in words.take(5)) w.id: true});
    expect(s.unlocked, contains('test_perfect'));
  });

  test('recall test questions use no options or hints', () {
    final s = buildTest([
      WordProgress(id: 'candid', learnedOn: '2026-10-01', due: '2026-10-02'),
    ], random: Random(3));
    expect(s.single.kind, StepKind.test);
    expect(s.single.options, isEmpty);
  });
}
