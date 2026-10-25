import 'dart:math';

import '../models/word.dart';

/// A constraint on the sentence the user writes, so each word gets used in
/// many situations, tenses, and forms instead of one comfortable pattern.
class SentenceChallenge {
  const SentenceChallenge(this.id, this.prompt, [this.check]);

  final String id;
  final String prompt;

  /// Returns why the sentence misses the challenge, or null if it meets it.
  final String? Function(String sentence)? check;
}

String? Function(String) _mustMatch(RegExp pattern, String error) =>
    (s) => pattern.hasMatch(s.toLowerCase()) ? null : error;

const _irregularPast = {
  'was',
  'were',
  'had',
  'did',
  'went',
  'said',
  'made',
  'took',
  'got',
  'felt',
  'thought',
  'knew',
  'saw',
  'came',
  'gave',
  'told',
  'found',
  'left',
  'kept',
  'brought',
  'began',
  'ran',
  'wrote',
  'spoke',
  'met',
  'sat',
  'stood',
  'lost',
  'paid',
  'sent',
  'spent',
  'built',
  'bought',
  'caught',
  'taught',
  'heard',
};

String? _checkPast(String s) {
  final tokens = s.toLowerCase().split(RegExp(r"[^a-z']+"));
  final past = tokens.any(
    (t) => _irregularPast.contains(t) || (t.length > 3 && t.endsWith('ed')),
  );
  return past ? null : 'Set it in the past: something that already happened.';
}

final List<SentenceChallenge> _general = [
  SentenceChallenge(
    'question',
    'Ask a question with it, the kind you might ask a coworker or friend.',
    (s) => s.trim().endsWith('?') ? null : 'Make it a question ending in "?".',
  ),
  SentenceChallenge(
    'negative',
    'Use it in a negative sentence (not, never, no…).',
    _mustMatch(
      RegExp(r"\b(not|never|no|nobody|nothing|none|neither|nor|without)\b|n't"),
      'Make it negative, with a word like not, never, or no.',
    ),
  ),
  SentenceChallenge(
    'past',
    'Tell a short story about something that already happened.',
    _checkPast,
  ),
  SentenceChallenge(
    'future',
    'Talk about something coming up (will, going to, next week…).',
    _mustMatch(
      RegExp(
        r"\b(will|won't|going to|gonna|tomorrow|next|soon|later|someday|plan|plans|planning)\b|'ll",
      ),
      'Point it at the future, with words like will, going to, or next.',
    ),
  ),
  SentenceChallenge(
    'opinion',
    'Give your opinion, starting with "I think", "I feel", or "In my opinion".',
    _mustMatch(
      RegExp(r"\b(i think|i feel|i believe|in my opinion|i'd say|i doubt)\b"),
      'Include "I think", "I feel", "I believe", or "In my opinion".',
    ),
  ),
  const SentenceChallenge(
    'work',
    'Write it as a line from a work or school email.',
  ),
  const SentenceChallenge('text', 'Write it as a casual text to a friend.'),
  const SentenceChallenge(
    'person',
    'Describe someone you know: a friend, family member, or coworker.',
  ),
];

const _altSpellings = {'sceptical', 'acknowledgement'};

/// British "-ise" spellings of words whose "-ize" form is also listed.
bool _isAltSpelling(String form, List<String> forms) {
  final us = form.replaceAll('is', 'iz');
  return us != form && forms.contains(us);
}

/// Every challenge that fits [word], including one per alternate form.
List<SentenceChallenge> challengesFor(Word word) => [
  ..._general,
  for (final form
      in word.forms
          .skip(1)
          .where(
            (f) => !_altSpellings.contains(f) && !_isAltSpelling(f, word.forms),
          ))
    SentenceChallenge(
      'form:$form',
      'Use the form "$form" in your sentence.',
      (s) => s.toLowerCase().split(RegExp(r"[^a-z\-']+")).contains(form)
          ? null
          : 'Use "$form" exactly, not another form of the word.',
    ),
];

/// Picks a challenge not yet done for this word, cycling once all are done.
SentenceChallenge pickChallenge(
  Word word,
  Iterable<String> done, {
  Random? random,
}) {
  final all = challengesFor(word);
  final fresh = all.where((c) => !done.contains(c.id)).toList();
  final pool = fresh.isEmpty ? all : fresh;
  return pool[(random ?? Random()).nextInt(pool.length)];
}
