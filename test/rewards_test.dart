import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/services/progress_store.dart';
import 'package:ms_wordly/services/rewards.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance(), clock: () => now);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = DateTime(2026, 10, 21, 9);
  });

  Future<void> finishDay(ProgressStore s) => s.completeSession(
    newWordResults: {for (final w in s.todaysNewWords) w.id: true},
    reviewResults: {for (final r in s.dueReviews) r.id: true},
  );

  test('daily session earns points plus first achievements once', () async {
    final s = await open();
    await finishDay(s);
    final ids = s.lastReward!.unlocked.map((a) => a.id);
    expect(ids, containsAll(['first_session', 'perfect']));
    expect(s.points, dailyPoints(1) + 20 + 25);

    final before = s.points;
    await s.completeSession(
      newWordResults: {for (final w in s.nextNewWords()) w.id: true},
      reviewResults: {},
    );
    expect(s.lastReward!.unlocked.map((a) => a.id), ['more_words']);
    expect(s.points, before + bonusRoundPoints + 20);
  });

  test('streak raises daily points and unlocks streak achievements', () async {
    final s = await open();
    for (var d = 0; d < 3; d++) {
      await finishDay(s);
      now = now.add(const Duration(days: 1));
    }
    expect(s.unlocked, contains('streak_3'));
    expect(dailyPoints(3), greaterThan(dailyPoints(1)));
    expect(dailyPoints(50), dailyPoints(10));
  });

  test('buy, equip, and persist the closet', () async {
    final s = await open();
    final bow = accessoriesById['bow']!;
    expect(await s.buy(bow), isFalse);
    s.points = 100;
    expect(await s.buy(bow), isTrue);
    expect(s.points, 60);
    expect(s.equipped[Slot.head], 'bow');
    expect(await s.buy(bow), isFalse);
    await s.toggleEquip(bow);
    expect(s.equipped[Slot.head], isNull);
    await s.toggleEquip(bow);
    await s.renameMascot('  Mochi ');

    final again = await open();
    expect(again.points, 60);
    expect(again.owned, {'bow'});
    expect(again.equipped[Slot.head], 'bow');
    expect(again.mascotName, 'Mochi');
  });
}
