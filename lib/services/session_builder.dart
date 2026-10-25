import 'dart:math';

import '../data/word_bank.dart';
import '../models/word.dart';
import 'answer_check.dart';
import 'progress_store.dart';
import 'sentence_challenges.dart';

enum StepKind {
  /// Meet the word: definition, what it replaces, example.
  learn,

  /// Pick the word that upgrades a plain phrase.
  choose,

  /// Type the word into a sentence.
  cloze,

  /// See the definition, type the word from memory.
  recall,

  /// Write your own sentence with the word.
  sentence,

  /// Type the word that upgrades one of its plain alternatives.
  swap,

  /// Fill the word back into a sentence you wrote earlier.
  own,

  /// Match several words to their meanings.
  match,

  /// Recall test: a meaning or situation only, no options or hints.
  test,
}

class SessionStep {
  const SessionStep(
    this.kind,
    this.word, {
    this.isReview = false,
    this.options = const [],
    this.isRetry = false,
    this.challenge,
    this.variant = 0,
    this.ownSentence,
    this.matchWords = const [],
  });

  final StepKind kind;
  final Word word;
  final bool isReview;
  final List<Word> options;
  final bool isRetry;

  /// The constraint for a [StepKind.sentence] step.
  final SentenceChallenge? challenge;

  /// Which plain alternative a [StepKind.swap] step uses.
  final int variant;

  /// The user's earlier sentence for a [StepKind.own] step.
  final String? ownSentence;

  /// The words in a [StepKind.match] step.
  final List<Word> matchWords;

  /// Identifies this exercise, so recent ones aren't repeated.
  String get key => switch (kind) {
    StepKind.swap => 'swap:$variant',
    StepKind.own => 'own:${ownSentence.hashCode}',
    _ => kind.name,
  };

  SessionStep retry() => SessionStep(
    kind,
    word,
    isReview: isReview,
    options: options,
    isRetry: true,
    challenge: challenge,
    variant: variant,
    ownSentence: ownSentence,
    matchWords: matchWords,
  );
}

/// Number of recent exercises per word that won't be repeated.
const recentLimit = 6;

/// Every production exercise available for a learned word.
List<SessionStep> exercisesFor(WordProgress p, Random rng) {
  final w = p.word;
  return [
    SessionStep(StepKind.cloze, w, isReview: true),
    SessionStep(StepKind.recall, w, isReview: true),
    for (var i = 0; i < w.insteadOf.length; i++)
      SessionStep(StepKind.swap, w, isReview: true, variant: i),
    for (final s in p.sentences.toSet())
      if (blankWord(s, w) != null)
        SessionStep(StepKind.own, w, isReview: true, ownSentence: s),
    SessionStep(
      StepKind.sentence,
      w,
      isReview: true,
      challenge: pickChallenge(w, p.challengesDone, random: rng),
    ),
  ];
}

/// Picks an exercise the user hasn't seen recently for this word. Each kind
/// of exercise is equally likely, however many variants it has.
SessionStep pickExercise(WordProgress p, Random rng) {
  final all = exercisesFor(p, rng);
  final fresh = all.where((e) => !p.recentExercises.contains(e.key)).toList();
  final pool = fresh.isEmpty ? all : fresh;
  final kinds = pool.map((e) => e.kind).toSet().toList();
  final kind = kinds[rng.nextInt(kinds.length)];
  final ofKind = pool.where((e) => e.kind == kind).toList();
  return ofKind[rng.nextInt(ofKind.length)];
}

List<Word> _optionsFor(Word word, List<Word> pool, Random rng) {
  final distractors = pool.where((w) => w.id != word.id).toList()..shuffle(rng);
  final extra =
      wordBank
          .where((w) => w.id != word.id && !distractors.contains(w))
          .toList()
        ..shuffle(rng);
  return [
    word,
    ...[...distractors, ...extra].take(3),
  ]..shuffle(rng);
}

List<SessionStep> buildSession(
  List<Word> newWords,
  List<WordProgress> reviews, {
  Random? random,
}) {
  final rng = random ?? Random();
  List<Word> shuffled() => [...newWords]..shuffle(rng);

  return [
    for (final p in reviews) pickExercise(p, rng),
    for (final w in newWords) SessionStep(StepKind.learn, w),
    for (final w in shuffled())
      SessionStep(StepKind.choose, w, options: _optionsFor(w, newWords, rng)),
    for (final w in shuffled()) SessionStep(StepKind.cloze, w),
    for (final w in shuffled()) SessionStep(StepKind.recall, w),
    for (final w in newWords)
      SessionStep(
        StepKind.sentence,
        w,
        challenge: pickChallenge(w, const [], random: rng),
      ),
  ];
}

/// Extra practice: a matching warm-up, then one exercise per word that
/// avoids what the user has done with it recently.
List<SessionStep> buildPractice(
  List<WordProgress> words, {
  List<WordProgress> learned = const [],
  Random? random,
}) {
  final rng = random ?? Random();
  final matchPool = <Word>{
    ...words.map((p) => p.word),
    ...(learned.map((p) => p.word).toList()..shuffle(rng)),
  }.take(4).toList();
  return [
    if (matchPool.length == 4)
      SessionStep(
        StepKind.match,
        matchPool.first,
        isReview: true,
        matchWords: matchPool,
      ),
    for (final p in words) pickExercise(p, rng),
  ];
}

/// A recall test: one free-recall question per word, cued by its meaning,
/// a sentence it fits, or a plain word it replaces. The variant is 0, 1, or
/// 2 plus the index of the plain word.
List<SessionStep> buildTest(List<WordProgress> words, {Random? random}) {
  final rng = random ?? Random();
  return [
    for (final p in words)
      SessionStep(
        StepKind.test,
        p.word,
        isReview: true,
        variant: switch (rng.nextInt(3)) {
          2 => 2 + rng.nextInt(p.word.insteadOf.length),
          final v => v,
        },
      ),
  ];
}
