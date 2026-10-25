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

/// The verdict on one learned word inside a free response.
class WordGrade {
  const WordGrade(this.word, this.verdict, this.feedback);

  final Word word;
  final UsageVerdict verdict;
  final String feedback;

  bool get passed => verdict != UsageVerdict.incorrect;
}

/// The verdict on a free response to a real-life prompt.
class ResponseGrade {
  const ResponseGrade(this.words, this.feedback, this.polished);

  final List<WordGrade> words;
  final String feedback;
  final String polished;
}

/// Judges how well learned words are used in a free response.
abstract class ResponseGrader {
  Future<ResponseGrade> gradeResponse(
    String scenario,
    String response,
    List<Word> words,
  );
}

const _responseSystem =
    'You are a warm but exacting vocabulary coach. The learner is building '
    'their active vocabulary for everyday speaking and writing. They were '
    'given a real-life situation and wrote a reply, choosing on their own '
    'which of their learned words to work in. For each target word, judge '
    'whether it is used with the right meaning, part of speech, collocation, '
    'and register, and whether it fits the situation naturally. Ignore small '
    'typos elsewhere.\n'
    'verdict: "correct" if a fluent speaker would use the word this way here; '
    '"almost" if the meaning is right but the phrasing or fit is off; '
    '"incorrect" if the meaning or grammar of the word is wrong.\n'
    'feedback (per word): one short sentence addressed to the learner '
    '("you").\n'
    'overall_feedback: one or two short sentences on how natural the reply '
    'sounds and, if it fits, one of the words where a learned word could '
    'have replaced a plainer one.\n'
    'polished_response: the learner\'s reply, minimally fixed, keeping their '
    'idea, tone, and the target words.';

const _responseSchema = {
  'type': 'object',
  'properties': {
    'words': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'word': {'type': 'string'},
          'verdict': {
            'type': 'string',
            'enum': ['correct', 'almost', 'incorrect'],
          },
          'feedback': {'type': 'string'},
        },
        'required': ['word', 'verdict', 'feedback'],
        'additionalProperties': false,
      },
    },
    'overall_feedback': {'type': 'string'},
    'polished_response': {'type': 'string'},
  },
  'required': ['words', 'overall_feedback', 'polished_response'],
  'additionalProperties': false,
};

/// Calls the Claude API straight from the device with the user's own key.
class ClaudeSentenceGrader implements SentenceGrader, ResponseGrader {
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
    final out = await _ask(
      _system,
      _schema,
      'Target word: ${word.word} (${word.partOfSpeech}): '
      '${word.definition}\n'
      'Challenge given: ${challenge.prompt}\n'
      'Learner\'s sentence: $sentence',
    );
    return GradeResult(
      UsageVerdict.values.byName(out['verdict'] as String),
      out['feedback'] as String,
      out['better_sentence'] as String,
    );
  }

  @override
  Future<ResponseGrade> gradeResponse(
    String scenario,
    String response,
    List<Word> words,
  ) async {
    final out = await _ask(
      _responseSystem,
      _responseSchema,
      'Situation: $scenario\n'
      'Target words:\n'
      '${words.map((w) => '- ${w.word} (${w.partOfSpeech}): ${w.definition}').join('\n')}\n'
      'Learner\'s reply: $response',
    );
    final byWord = {
      for (final g in (out['words'] as List).cast<Map<String, dynamic>>())
        (g['word'] as String).toLowerCase(): g,
    };
    return ResponseGrade(
      [
        for (final w in words)
          if (byWord[w.word.toLowerCase()] case final g?)
            WordGrade(
              w,
              UsageVerdict.values.byName(g['verdict'] as String),
              g['feedback'] as String,
            )
          else
            WordGrade(
              w,
              UsageVerdict.almost,
              "Claude didn't comment on this one.",
            ),
      ],
      out['overall_feedback'] as String,
      out['polished_response'] as String,
    );
  }

  Future<Map<String, dynamic>> _ask(
    String system,
    Map<String, dynamic> schema,
    String content,
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
                'format': {'type': 'json_schema', 'schema': schema},
              },
              'system': system,
              'messages': [
                {'role': 'user', 'content': content},
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
      throw GradeException("Claude couldn't check this.");
    }
    final text = (body['content'] as List)
        .cast<Map<String, dynamic>>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw GradeException("Claude's answer was cut off. Try again.");
    }
  }
}
