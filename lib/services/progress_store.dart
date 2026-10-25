import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/word_bank.dart';
import '../models/word.dart';
import 'rewards.dart';
import 'session_builder.dart' show recentLimit;

const int wordsPerDay = 3;

/// Words in each day's "use it today" mission.
const int missionSize = 3;

/// Words in a recall test.
const int testSize = 10;
const int maxReviewsPerDay = 12;

/// Level at which a word counts as part of your active vocabulary.
const int masteredLevel = 5;

/// Days until the next review once a word reaches a level.
const Map<int, int> _intervals = {1: 1, 2: 3, 3: 7, 4: 14, 5: 30, 6: 60};
int intervalFor(int level) => _intervals[level] ?? 120;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String addDays(String key, int days) =>
    dayKey(parseDay(key).add(Duration(days: days)));

class WordProgress {
  WordProgress({
    required this.id,
    required this.learnedOn,
    required this.due,
    this.level = 1,
    this.correct = 0,
    this.wrong = 0,
    this.usedInLife = 0,
    this.lastUsedOn,
    List<String>? sentences,
    List<String>? challengesDone,
    List<String>? recentExercises,
  }) : sentences = sentences ?? [],
       challengesDone = challengesDone ?? [],
       recentExercises = recentExercises ?? [];

  final String id;
  final String learnedOn;
  String due;
  int level;
  int correct;
  int wrong;
  int usedInLife;
  String? lastUsedOn;
  final List<String> sentences;

  /// Sentence challenge ids already completed, so new ones rotate in.
  final List<String> challengesDone;

  /// Keys of the latest exercises done with this word, newest last.
  final List<String> recentExercises;

  bool get mastered => level >= masteredLevel;
  Word get word => wordsById[id]!;

  Map<String, dynamic> toJson() => {
    'id': id,
    'learnedOn': learnedOn,
    'due': due,
    'level': level,
    'correct': correct,
    'wrong': wrong,
    'usedInLife': usedInLife,
    'lastUsedOn': lastUsedOn,
    'sentences': sentences,
    'challengesDone': challengesDone,
    'recentExercises': recentExercises,
  };

  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
    id: j['id'] as String,
    learnedOn: j['learnedOn'] as String,
    due: j['due'] as String,
    level: j['level'] as int,
    correct: j['correct'] as int? ?? 0,
    wrong: j['wrong'] as int? ?? 0,
    usedInLife: j['usedInLife'] as int? ?? 0,
    lastUsedOn: j['lastUsedOn'] as String?,
    sentences: (j['sentences'] as List?)?.cast<String>(),
    challengesDone: (j['challengesDone'] as List?)?.cast<String>(),
    recentExercises: (j['recentExercises'] as List?)?.cast<String>(),
  );
}

/// All learning state, persisted as one JSON blob.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    _load();
  }

  static const _key = 'ms_wordly_state_v1';
  static const _apiKeyKey = 'ms_wordly_anthropic_api_key';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  final Map<String, WordProgress> progress = {};
  final Set<String> completedDays = {};
  int streak = 0;
  int bestStreak = 0;
  String? lastCompleted;
  String? planDate;
  List<String> planWordIds = [];

  /// Today's "use it today" mission: learned words to use for real.
  String? missionDate;
  List<String> missionWordIds = [];
  String? missionDoneDate;
  int missionsCompleted = 0;

  int testsTaken = 0;
  int perfectTests = 0;
  int useItTests = 0;

  /// Most words used correctly in one use-it test.
  int bestUseIt = 0;

  /// Difficulty of new words; null mixes all levels.
  Difficulty? difficulty = Difficulty.stretch;

  // Rewards: points, the mascot's closet, achievements, and activity counts.
  int points = 0;
  String mascotName = 'Lexi';
  final Set<String> owned = {};
  final Map<Slot, String> equipped = {};
  final Set<String> unlocked = {};
  int sessionsCompleted = 0;
  int perfectSessions = 0;
  int practiceRounds = 0;
  int bonusRounds = 0;

  /// What the most recent session earned, for the celebration screen.
  Reward? lastReward;

  String get today => dayKey(_clock());
  DateTime get now => _clock();

  static Future<ProgressStore> open() async =>
      ProgressStore(await SharedPreferences.getInstance());

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    for (final p in (j['progress'] as List)) {
      final wp = WordProgress.fromJson(p as Map<String, dynamic>);
      if (wordsById.containsKey(wp.id)) progress[wp.id] = wp;
    }
    completedDays.addAll((j['completedDays'] as List).cast<String>());
    streak = j['streak'] as int;
    bestStreak = j['bestStreak'] as int;
    lastCompleted = j['lastCompleted'] as String?;
    planDate = j['planDate'] as String?;
    planWordIds = (j['planWordIds'] as List).cast<String>();
    missionDate = j['missionDate'] as String?;
    missionWordIds = [
      ...?(j['missionWordIds'] as List?)?.cast<String>().where(
        progress.containsKey,
      ),
    ];
    missionDoneDate = j['missionDoneDate'] as String?;
    final d = j['difficulty'] as String?;
    if (j.containsKey('difficulty')) {
      difficulty = d == null ? null : Difficulty.values.byName(d);
    }
    final r = j['rewards'] as Map<String, dynamic>?;
    if (r == null) return;
    points = r['points'] as int;
    mascotName = r['mascotName'] as String;
    owned.addAll((r['owned'] as List).cast<String>());
    for (final e in (r['equipped'] as Map<String, dynamic>).entries) {
      if (accessoriesById.containsKey(e.value)) {
        equipped[Slot.values.byName(e.key)] = e.value as String;
      }
    }
    unlocked.addAll((r['unlocked'] as List).cast<String>());
    sessionsCompleted = r['sessionsCompleted'] as int;
    perfectSessions = r['perfectSessions'] as int;
    practiceRounds = r['practiceRounds'] as int;
    bonusRounds = r['bonusRounds'] as int;
    missionsCompleted = r['missionsCompleted'] as int? ?? 0;
    testsTaken = r['testsTaken'] as int? ?? 0;
    perfectTests = r['perfectTests'] as int? ?? 0;
    useItTests = r['useItTests'] as int? ?? 0;
    bestUseIt = r['bestUseIt'] as int? ?? 0;
  }

  Future<void> _save() async {
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode({
        'progress': progress.values.map((p) => p.toJson()).toList(),
        'completedDays': completedDays.toList(),
        'streak': streak,
        'bestStreak': bestStreak,
        'lastCompleted': lastCompleted,
        'planDate': planDate,
        'planWordIds': planWordIds,
        'missionDate': missionDate,
        'missionWordIds': missionWordIds,
        'missionDoneDate': missionDoneDate,
        'difficulty': difficulty?.name,
        'rewards': {
          'points': points,
          'mascotName': mascotName,
          'owned': owned.toList(),
          'equipped': {for (final e in equipped.entries) e.key.name: e.value},
          'unlocked': unlocked.toList(),
          'sessionsCompleted': sessionsCompleted,
          'perfectSessions': perfectSessions,
          'practiceRounds': practiceRounds,
          'bonusRounds': bonusRounds,
          'missionsCompleted': missionsCompleted,
          'testsTaken': testsTaken,
          'perfectTests': perfectTests,
          'useItTests': useItTests,
          'bestUseIt': bestUseIt,
        },
      }),
    );
  }

  /// The streak as it stands now: it is broken once a whole day is missed.
  int get currentStreak {
    final last = lastCompleted;
    if (last == null) return 0;
    if (last == today || last == addDays(today, -1)) return streak;
    return 0;
  }

  bool get doneToday => completedDays.contains(today);

  /// Today's new words, picked once per day in word bank order.
  List<Word> get todaysNewWords {
    _ensurePlan();
    return planWordIds.map((id) => wordsById[id]!).toList();
  }

  void _ensurePlan() {
    if (planDate == today) return;
    planDate = today;
    planWordIds = _unlearned(const {})
        .take(wordsPerDay)
        .map((w) => w.id)
        .toList();
    _persist();
  }

  /// Unlearned words at the chosen difficulty, then any others once those
  /// run out.
  Iterable<Word> _unlearned(Set<String> exclude) {
    bool fresh(Word w) =>
        !progress.containsKey(w.id) && !exclude.contains(w.id);
    return [
      ...wordsAt(difficulty).where(fresh),
      ...wordBank.where((w) => w.difficulty != difficulty && fresh(w)),
    ];
  }

  /// Changes the difficulty of new words. Today's words are re-picked if
  /// today's session hasn't been finished yet.
  Future<void> setDifficulty(Difficulty? d) async {
    difficulty = d;
    if (!doneToday) planDate = null;
    await _save();
  }

  List<WordProgress> get dueReviews {
    _ensurePlan();
    final due =
        progress.values
            .where(
              (p) => p.due.compareTo(today) <= 0 && !planWordIds.contains(p.id),
            )
            .toList()
          ..sort((a, b) => a.due.compareTo(b.due));
    return due.take(maxReviewsPerDay).toList();
  }

  /// Words beyond today's plan, for learning more after the daily session.
  List<Word> nextNewWords([int count = wordsPerDay]) {
    _ensurePlan();
    return _unlearned(planWordIds.toSet()).take(count).toList();
  }

  List<Word> get learnedToday => progress.values
      .where((p) => p.learnedOn == today)
      .map((p) => p.word)
      .toList();

  /// Learned words for extra practice, favoring the least solid ones.
  List<WordProgress> practiceSet({int count = 5, Random? random}) {
    final rng = random ?? Random();
    final byLevel = progress.values.toList()
      ..shuffle(rng)
      ..sort((a, b) => a.level.compareTo(b.level));
    return (byLevel.take(count * 2).toList()..shuffle(rng))
        .take(count)
        .toList();
  }

  List<WordProgress> get learnedWords =>
      progress.values.toList()
        ..sort((a, b) => b.learnedOn.compareTo(a.learnedOn));

  int get masteredCount => progress.values.where((p) => p.mastered).length;
  int get usedInLifeCount =>
      progress.values.fold(0, (sum, p) => sum + p.usedInLife);
  int get wordsRemaining => wordBank.length - progress.length;

  /// Records a finished daily session. The result maps take a word id to
  /// whether every exercise for that word was answered right the first time.
  Future<void> completeSession({
    required Map<String, bool> newWordResults,
    required Map<String, bool> reviewResults,
    Map<String, List<String>> sentences = const {},
    Map<String, List<String>> challenges = const {},
    Map<String, List<String>> exercises = const {},
  }) async {
    final t = today;
    for (final e in newWordResults.entries) {
      final p =
          progress[e.key] ??
          WordProgress(id: e.key, learnedOn: t, due: addDays(t, 1));
      if (e.value) {
        p.correct++;
      } else {
        p.wrong++;
      }
      progress[e.key] = p;
    }
    for (final e in reviewResults.entries) {
      final p = progress[e.key];
      if (p == null) continue;
      if (e.value) {
        p.correct++;
        p.level++;
        p.due = addDays(t, intervalFor(p.level));
      } else {
        p.wrong++;
        p.level = (p.level - 1).clamp(1, 99);
        p.due = addDays(t, 1);
      }
    }
    _recordWork(sentences, challenges, exercises);
    final int earned;
    if (!completedDays.contains(t)) {
      completedDays.add(t);
      streak = lastCompleted == addDays(t, -1) ? streak + 1 : 1;
      if (streak > bestStreak) bestStreak = streak;
      lastCompleted = t;
      sessionsCompleted++;
      earned = dailyPoints(streak);
    } else {
      bonusRounds++;
      earned = bonusRoundPoints;
    }
    final results = [...newWordResults.values, ...reviewResults.values];
    if (results.isNotEmpty && results.every((ok) => ok)) perfectSessions++;
    lastReward = _award(earned);
    await _save();
  }

  /// Records extra practice. It never moves a word further out, but a miss
  /// brings the word back tomorrow.
  Future<void> completePractice({
    required Map<String, bool> results,
    Map<String, List<String>> sentences = const {},
    Map<String, List<String>> challenges = const {},
    Map<String, List<String>> exercises = const {},
  }) async {
    final tomorrow = addDays(today, 1);
    for (final e in results.entries) {
      final p = progress[e.key];
      if (p == null) continue;
      if (e.value) {
        p.correct++;
      } else {
        p.wrong++;
        if (p.due.compareTo(tomorrow) > 0) p.due = tomorrow;
      }
    }
    _recordWork(sentences, challenges, exercises);
    practiceRounds++;
    lastReward = _award(practicePoints);
    await _save();
  }

  void _recordWork(
    Map<String, List<String>> sentences,
    Map<String, List<String>> challenges,
    Map<String, List<String>> exercises,
  ) {
    for (final e in sentences.entries) {
      progress[e.key]?.sentences.addAll(e.value.map((s) => s.trim()));
    }
    for (final e in challenges.entries) {
      progress[e.key]?.challengesDone.addAll(e.value);
    }
    for (final e in exercises.entries) {
      final recent = progress[e.key]?.recentExercises;
      if (recent == null) continue;
      recent.addAll(e.value);
      if (recent.length > recentLimit) {
        recent.removeRange(0, recent.length - recentLimit);
      }
    }
  }

  /// Today's mission: learned words to use in a real conversation or
  /// message. Picked once a day, and topped up if fewer words were learned
  /// when it was picked.
  List<Word> get mission {
    final t = today;
    if (missionDate != t) {
      missionDate = t;
      missionWordIds = [];
    }
    if (missionWordIds.length < missionSize &&
        progress.length > missionWordIds.length) {
      missionWordIds.addAll(
        _missionCandidates()
            .take(missionSize - missionWordIds.length)
            .map((p) => p.id),
      );
      _persist();
    }
    return missionWordIds.map((id) => wordsById[id]!).toList();
  }

  /// Words that most need real use: least used, then not yet active, then
  /// most recently learned. Words used in the last two days wait their turn.
  List<WordProgress> _missionCandidates() {
    final yesterday = addDays(today, -1);
    bool usedLately(WordProgress p) =>
        p.lastUsedOn != null && p.lastUsedOn!.compareTo(yesterday) >= 0;
    final pool =
        progress.values.where((p) => !missionWordIds.contains(p.id)).toList()
          ..sort((a, b) {
            for (final c in [
              (usedLately(a) ? 1 : 0) - (usedLately(b) ? 1 : 0),
              a.usedInLife.compareTo(b.usedInLife),
              (a.mastered ? 1 : 0) - (b.mastered ? 1 : 0),
              b.learnedOn.compareTo(a.learnedOn),
            ]) {
              if (c != 0) return c;
            }
            return a.id.compareTo(b.id);
          });
    return pool;
  }

  bool get missionDone => missionDoneDate == today;

  /// Using a word in real life is the best signal it is active vocabulary.
  /// Returns what it earned, including the mission bonus when this was the
  /// last mission word.
  Future<Reward?> markUsedInLife(String id) async {
    final p = progress[id];
    if (p == null || p.lastUsedOn == today) return null;
    p.usedInLife++;
    p.lastUsedOn = today;
    var base = usedInLifePoints;
    final words = mission;
    if (!missionDone &&
        words.length == missionSize &&
        words.every((w) => usedToday(w.id))) {
      missionDoneDate = today;
      missionsCompleted++;
      base += missionPoints;
    }
    final reward = _award(base);
    await _save();
    return reward;
  }

  /// Learned words for a recall test, oldest reviews first so words that
  /// haven't come up in a while are checked.
  List<WordProgress> testSet({int count = testSize, Random? random}) {
    final rng = random ?? Random();
    final words = progress.values.toList()..shuffle(rng);
    words.sort((a, b) => b.due.compareTo(a.due));
    return (words.take(count).toList()..shuffle(rng));
  }

  /// Records a recall test. Free recall is the real test of active
  /// vocabulary, so a word that wasn't recalled drops a level and comes
  /// back tomorrow.
  Future<void> completeTest(Map<String, bool> results) async {
    final tomorrow = addDays(today, 1);
    for (final e in results.entries) {
      final p = progress[e.key];
      if (p == null) continue;
      if (e.value) {
        p.correct++;
      } else {
        p.wrong++;
        p.level = (p.level - 1).clamp(1, 99);
        if (p.due.compareTo(tomorrow) > 0) p.due = tomorrow;
      }
    }
    testsTaken++;
    if (results.length >= 5 && results.values.every((ok) => ok)) {
      perfectTests++;
    }
    final right = results.values.where((ok) => ok).length;
    lastReward = _award(testPoints + right);
    await _save();
  }

  /// Records a use-it test: each learned word the user chose to use and
  /// whether it was used well. Sentences are kept for later exercises, and
  /// a misused word comes back tomorrow.
  Future<void> completeUseItTest({
    required Map<String, bool> results,
    Map<String, List<String>> sentences = const {},
  }) async {
    final tomorrow = addDays(today, 1);
    for (final e in results.entries) {
      final p = progress[e.key];
      if (p == null) continue;
      if (e.value) {
        p.correct++;
      } else {
        p.wrong++;
        if (p.due.compareTo(tomorrow) > 0) p.due = tomorrow;
      }
    }
    _recordWork(sentences, const {}, const {});
    useItTests++;
    final right = results.values.where((ok) => ok).length;
    if (right > bestUseIt) bestUseIt = right;
    lastReward = _award(testPoints + 2 * right);
    await _save();
  }

  int get sentenceCount =>
      progress.values.fold<int>(0, (sum, p) => sum + p.sentences.length);

  /// Adds [base] points plus any achievements that are newly earned.
  Reward _award(int base) {
    final fresh = [
      for (final a in achievements)
        if (!unlocked.contains(a.id) && a.earned(this)) a,
    ];
    unlocked.addAll(fresh.map((a) => a.id));
    final total = base + fresh.fold<int>(0, (sum, a) => sum + a.points);
    points += total;
    return Reward(total, fresh);
  }

  Future<bool> buy(Accessory a) async {
    if (owned.contains(a.id) || points < a.price) return false;
    points -= a.price;
    owned.add(a.id);
    equipped[a.slot] = a.id;
    await _save();
    return true;
  }

  Future<void> toggleEquip(Accessory a) async {
    if (!owned.contains(a.id)) return;
    if (equipped[a.slot] == a.id) {
      equipped.remove(a.slot);
    } else {
      equipped[a.slot] = a.id;
    }
    await _save();
  }

  Future<void> renameMascot(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    mascotName = n.length > 16 ? n.substring(0, 16) : n;
    await _save();
  }

  bool usedToday(String id) => progress[id]?.lastUsedOn == today;

  /// The user's own Claude API key for sentence checking. It stays on
  /// this device.
  String? get apiKey {
    final k = _prefs.getString(_apiKeyKey)?.trim();
    return k == null || k.isEmpty ? null : k;
  }

  Future<void> setApiKey(String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      await _prefs.remove(_apiKeyKey);
    } else {
      await _prefs.setString(_apiKeyKey, k);
    }
    notifyListeners();
  }
}
