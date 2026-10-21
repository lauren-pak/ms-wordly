import 'package:flutter_test/flutter_test.dart';
import 'package:ms_wordly/data/word_bank.dart';
import 'package:ms_wordly/services/answer_check.dart';

void main() {
  final mitigate = wordsById['mitigate']!;

  test('exact answer is correct, ignoring case and spaces', () {
    expect(checkTyped('  Mitigate ', mitigate), Verdict.correct);
  });

  test('one typo counts as close spelling', () {
    expect(checkTyped('mitigat', mitigate), Verdict.closeSpelling);
  });

  test('other form in a fill-in is flagged but passes', () {
    expect(
      checkTyped('mitigated', mitigate, exact: 'mitigate'),
      Verdict.wrongForm,
    );
    expect(Verdict.wrongForm.passed, isTrue);
  });

  test('any form is fine when recalling from the definition', () {
    expect(checkTyped('mitigating', mitigate), Verdict.correct);
  });

  test('wrong word fails', () {
    expect(checkTyped('reduce', mitigate), Verdict.wrong);
    expect(checkTyped('', mitigate), Verdict.wrong);
  });

  test('sentence must contain a form of the word', () {
    expect(sentenceUsesWord('We mitigated the risk early.', mitigate), isTrue);
    expect(sentenceUsesWord('We reduced the risk early.', mitigate), isFalse);
    expect(wordCount('one two  three'), 3);
  });
}
