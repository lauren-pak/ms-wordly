import 'dart:math';

import '../data/word_bank.dart';
import '../models/word.dart';
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
}

class SessionStep {
  const SessionStep(
    this.kind,
    this.word, {
    this.isReview = false,
    this.options = const [],
    this.isRetry = false,
    this.challenge,
  });

  final StepKind kind;
  final Word word;
  final bool isReview;
  final List<Word> options;
  final bool isRetry;

  /// The constraint for a [StepKind.sentence] step.
  final SentenceChallenge? challenge;

  SessionStep retry() => SessionStep(
    kind,
    word,
    isReview: isReview,
    options: options,
    isRetry: true,
    challenge: challenge,
  );
}

/// Review exercises rotate as a word levels up, so each review asks for
/// the word in a different way.
StepKind reviewKindFor(int level) => switch (level % 3) {
  1 => StepKind.cloze,
  2 => StepKind.recall,
  _ => StepKind.sentence,
};

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
  SessionStep step(StepKind kind, Word w, {bool isReview = false}) =>
      SessionStep(
        kind,
        w,
        isReview: isReview,
        challenge: kind == StepKind.sentence
            ? pickChallenge(
                w,
                _progressOf(reviews, w)?.challengesDone ?? const [],
                random: rng,
              )
            : null,
      );
  List<Word> shuffled() => [...newWords]..shuffle(rng);

  return [
    for (final p in reviews)
      step(reviewKindFor(p.level), p.word, isReview: true),
    for (final w in newWords) SessionStep(StepKind.learn, w),
    for (final w in shuffled())
      SessionStep(StepKind.choose, w, options: _optionsFor(w, newWords, rng)),
    for (final w in shuffled()) SessionStep(StepKind.cloze, w),
    for (final w in shuffled()) SessionStep(StepKind.recall, w),
    for (final w in newWords) step(StepKind.sentence, w),
  ];
}

WordProgress? _progressOf(List<WordProgress> reviews, Word w) {
  for (final p in reviews) {
    if (p.id == w.id) return p;
  }
  return null;
}

/// Extra practice: one production exercise per word, in a random style.
List<SessionStep> buildPractice(List<WordProgress> words, {Random? random}) {
  final rng = random ?? Random();
  const kinds = [StepKind.cloze, StepKind.recall, StepKind.sentence];
  return [
    for (final p in words)
      if (kinds[rng.nextInt(kinds.length)] case final kind)
        SessionStep(
          kind,
          p.word,
          isReview: true,
          challenge: kind == StepKind.sentence
              ? pickChallenge(p.word, p.challengesDone, random: rng)
              : null,
        ),
  ];
}
