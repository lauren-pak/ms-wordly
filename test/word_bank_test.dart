import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/data/word_bank.dart';
import 'package:ms_wordly/models/word.dart';

void main() {
  test('every difficulty has plenty of words', () {
    for (final d in Difficulty.values) {
      expect(wordsAt(d).length, greaterThanOrEqualTo(30), reason: d.name);
    }
    expect(wordsAt(null), wordBank);
  });

  test('word ids are unique', () {
    expect(wordsById.length, wordBank.length);
  });

  for (final w in wordBank) {
    test('${w.word} data is consistent', () {
      expect(w.cloze, contains('___'));
      expect(w.forms, contains(w.word));
      expect(w.forms, contains(w.clozeAnswer));
      expect(w.insteadOf, isNotEmpty);
      final example = w.example.toLowerCase();
      expect(
        w.forms.any((f) => RegExp('\\b$f\\b').hasMatch(example)),
        isTrue,
        reason: 'example should use the word',
      );
    });
  }
}
