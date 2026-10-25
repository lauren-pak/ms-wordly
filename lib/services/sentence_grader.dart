import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/word.dart';
import 'sentence_challenges.dart';

enum UsageVerdict { correct, almost, incorrect }

class GradeResult {
  const GradeResult(this.verdict, this.feedback, this.betterSentence);

  final UsageVerdict verdict;
  final String feedback;
  final String betterSentence;

  bool get passed => verdict != UsageVerdict.incorrect;
}

class GradeException implements Exception {
  GradeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Judges whether a sentence uses a word correctly.
abstract class SentenceGrader {
  Future<GradeResult> grade(
    Word word,
    SentenceChallenge challenge,
    String sentence,
  );
}

const _system =
    'You are a warm but exacting vocabulary coach. The learner is building '
    'their active vocabulary for everyday speaking and writing. Judge only '
    'whether the target word is used with the right meaning, part of speech, '
    'collocation, and register, and whether the sentence sounds natural. '
    'Ignore small typos elsewhere in the sentence.\n'
    'verdict: "correct" if a fluent speaker would use the word this way; '
    '"almost" if the meaning is right but the phrasing or collocation is '
    'off; "incorrect" if the meaning or grammar of the word is wrong.\n'
    'feedback: one or two short sentences addressed to the learner ("you"). '
    'Say what works or exactly what is off.\n'
    'better_sentence: the learner\'s own sentence, minimally fixed, or '
    'lightly polished if it was already correct. Keep their idea and the '
    'challenge they were given.';

const _schema = {
  'type': 'object',
  'properties': {
    'verdict': {
      'type': 'string',
      'enum': ['correct', 'almost', 'incorrect'],
    },
    'feedback': {'type': 'string'},
    'better_sentence': {'type': 'string'},
  },
  'required': ['verdict', 'feedback', 'better_sentence'],
  'additionalProperties': false,
};

/// Calls the Claude API straight from the device with the user's own key.
class ClaudeSentenceGrader implements SentenceGrader {
  ClaudeSentenceGrader(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  @override
  Future<GradeResult> grade(
    Word word,
    SentenceChallenge challenge,
    String sentence,
  ) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2026-10-21',
              'anthropic-beta': 'server-side-fallback-2026-07-01',
              'anthropic-dangerous-direct-browser-access': 'true',
            },
            body: jsonEncode({
              'model': 'claude-opus-5-5',
              'max_tokens': 4000,
              'fallbacks': 'default',
              'output_config': {
                'effort': 'low',
                'format': {'type': 'json_schema', 'schema': _schema},
              },
              'system': _system,
              'messages': [
                {
                  'role': 'user',
                  'content':
                      'Target word: ${word.word} (${word.partOfSpeech}): '
                      '${word.definition}\n'
                      'Challenge given: ${challenge.prompt}\n'
                      'Learner\'s sentence: $sentence',
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      throw GradeException("Couldn't reach Claude. Check your connection.");
    }

    if (res.statusCode == 401) {
      throw GradeException('Your API key was rejected. Check it in Settings.');
    }
    if (res.statusCode != 200) {
      throw GradeException('Claude had a problem (error ${res.statusCode}).');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (body['stop_reason'] == 'refusal') {
      throw GradeException("Claude couldn't check this sentence.");
    }
    final text = (body['content'] as List)
        .cast<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    final Map<String, dynamic> out;
    try {
      out = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw GradeException("Claude's answer was cut off. Try again.");
    }
    return GradeResult(
      UsageVerdict.values.byName(out['verdict'] as String),
      out['feedback'] as String,
      out['better_sentence'] as String,
    );
  }
}
