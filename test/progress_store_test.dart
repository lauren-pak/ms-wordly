import 'package:flutter_test/flutter_test.dart';
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
    for (final kind in StepKind.values) {
      expect(steps.where((st) => st.kind == kind), hasLength(3));
    }
    final choose = steps.firstWhere((st) => st.kind == StepKind.choose);
    expect(choose.options, hasLength(4));
    expect(choose.options, contains(choose.word));
  });
}
