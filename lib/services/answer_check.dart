import '../models/word.dart';

enum Verdict { correct, closeSpelling, wrongForm, wrong }

extension VerdictX on Verdict {
  bool get passed => this != Verdict.wrong;
}

String _normalize(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z\- ]'), '');

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [
        prev[j] + 1,
        cur[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

bool _nearMiss(String typed, String target) =>
    target.length >= 5 && _levenshtein(typed, target) == 1;

/// Checks a typed answer. When [exact] is set (fill-in-the-blank), other
/// forms of the word are accepted but flagged as [Verdict.wrongForm].
Verdict checkTyped(String input, Word word, {String? exact}) {
  final typed = _normalize(input);
  if (typed.isEmpty) return Verdict.wrong;
  final target = exact ?? word.word;
  if (typed == target) return Verdict.correct;
  if (word.forms.contains(typed)) {
    return exact == null ? Verdict.correct : Verdict.wrongForm;
  }
  if (_nearMiss(typed, target)) return Verdict.closeSpelling;
  if (word.forms.any((f) => _nearMiss(typed, f))) return Verdict.closeSpelling;
  return Verdict.wrong;
}

/// Whether a sentence the user wrote actually uses the word.
bool sentenceUsesWord(String sentence, Word word) {
  final tokens = sentence
      .toLowerCase()
      .split(RegExp(r"[^a-z\-']+"))
      .where((t) => t.isNotEmpty);
  return tokens.any(word.forms.contains);
}

int wordCount(String sentence) =>
    sentence.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length;

Set<String> _tokens(String s) => s
    .toLowerCase()
    .split(RegExp(r"[^a-z']+"))
    .where((t) => t.isNotEmpty)
    .toSet();

/// Word overlap between two sentences, from 0 (nothing shared) to 1.
double similarity(String a, String b) {
  final ta = _tokens(a);
  final tb = _tokens(b);
  if (ta.isEmpty || tb.isEmpty) return 0;
  return ta.intersection(tb).length / ta.union(tb).length;
}

/// The earlier sentence [sentence] is too close to, if any.
String? tooSimilarTo(String sentence, Iterable<String> earlier) {
  for (final e in earlier) {
    if (similarity(sentence, e) >= 0.6) return e;
  }
  return null;
}
