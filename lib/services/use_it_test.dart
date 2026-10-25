import 'dart:math';

import '../data/scenarios.dart';
import '../models/word.dart';
import 'answer_check.dart';

/// Prompts in one use-it test.
const int useItRounds = 3;

/// Picks different scenarios for a use-it test.
List<String> pickScenarios({int count = useItRounds, Random? random}) =>
    ([...scenarios]..shuffle(random ?? Random())).take(count).toList();

/// Learned words that appear in [text], in any of their forms.
List<Word> wordsUsedIn(String text, Iterable<Word> learned) => [
  for (final w in learned)
    if (sentenceUsesWord(text, w)) w,
];

/// The sentence in [text] that contains [word], to save with the word.
String sentenceWith(String text, Word word) {
  final sentences = text
      .split(RegExp(r'(?<=[.!?])\s+|\n+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  return sentences.firstWhere(
    (s) => sentenceUsesWord(s, word),
    orElse: () => text.trim(),
  );
}
