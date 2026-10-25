import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/answer_check.dart';
import '../services/sentence_challenges.dart';
import '../services/sentence_grader.dart';

typedef OnAnswered = void Function(
  bool passed, {
  String? sentence,
  String? challengeId,
});

/// Bottom panel shown after an answer is checked.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.passed,
    required this.title,
    required this.onContinue,
    this.detail,
  });

  final bool passed;
  final String title;
  final String? detail;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = passed ? scheme.primaryContainer : scheme.errorContainer;
    final fg = passed ? scheme.onPrimaryContainer : scheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(passed ? Icons.check_circle : Icons.cancel, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(detail!, style: TextStyle(color: fg)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scaffold extends StatelessWidget {
  const _Scaffold({required this.label, required this.children, this.bottom});

  final String label;
  final List<Widget> children;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
        if (bottom != null)
          Padding(padding: const EdgeInsets.all(16), child: bottom),
      ],
    );
  }
}

class WordCard extends StatelessWidget {
  const WordCard({super.key, required this.word});

  final Word word;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          word.word,
          style: text.displaySmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          word.partOfSpeech,
          style: text.titleMedium?.copyWith(
            fontStyle: FontStyle.italic,
            color: scheme.secondary,
          ),
        ),
        const SizedBox(height: 16),
        Text(word.definition, style: text.titleLarge),
        const SizedBox(height: 20),
        Text('Use it instead of', style: text.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in word.insteadOf)
              Chip(label: Text('"$s"'), visualDensity: VisualDensity.compact),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            word.example,
            style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      ],
    );
  }
}

class LearnStepView extends StatelessWidget {
  const LearnStepView({super.key, required this.word, required this.onDone});

  final Word word;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _Scaffold(
      label: 'New word',
      bottom: SizedBox(
        width: double.infinity,
        child: FilledButton(onPressed: onDone, child: const Text('Got it')),
      ),
      children: [
        WordCard(word: word),
        const SizedBox(height: 16),
        Text(
          'Say it out loud once. Hearing yourself use it helps it stick.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class ChooseStepView extends StatefulWidget {
  const ChooseStepView({
    super.key,
    required this.word,
    required this.options,
    required this.onAnswered,
  });

  final Word word;
  final List<Word> options;
  final OnAnswered onAnswered;

  @override
  State<ChooseStepView> createState() => _ChooseStepViewState();
}

class _ChooseStepViewState extends State<ChooseStepView> {
  Word? picked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = picked?.id == widget.word.id;
    return _Scaffold(
      label: 'Upgrade the phrase',
      bottom: picked == null
          ? null
          : FeedbackPanel(
              passed: passed,
              title: passed ? 'Exactly.' : 'It was "${widget.word.word}".',
              detail: widget.word.example,
              onContinue: () => widget.onAnswered(passed),
            ),
      children: [
        Text(
          'Which word could you use instead of',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          '"${widget.word.insteadOf.first}"?',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        for (final o in widget.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                disabledForegroundColor: scheme.onSurface,
                backgroundColor: picked == null
                    ? null
                    : o.id == widget.word.id
                    ? scheme.primaryContainer
                    : o.id == picked!.id
                    ? scheme.errorContainer
                    : null,
              ),
              onPressed: picked == null
                  ? () => setState(() => picked = o)
                  : null,
              child: Text(o.word, style: const TextStyle(fontSize: 18)),
            ),
          ),
      ],
    );
  }
}

/// What a typed exercise shows and expects.
class TypePrompt {
  const TypePrompt({
    required this.label,
    required this.body,
    required this.target,
    required this.detail,
    this.lead,
    this.note,
    this.exact = false,
    this.hint = true,
  });

  /// A recall test question with no hint. See [buildTest] for variants.
  factory TypePrompt.test(Word w, int variant) => switch (variant) {
    0 => TypePrompt(
      label: 'Recall test',
      lead: 'Which word means:',
      body: w.definition,
      note: '(${w.partOfSpeech})',
      target: w.word,
      detail: w.example,
      hint: false,
    ),
    1 => TypePrompt(
      label: 'Recall test',
      lead: 'Which word fits here?',
      body: w.cloze,
      target: w.clozeAnswer,
      detail: w.cloze.replaceFirst('___', w.clozeAnswer),
      hint: false,
    ),
    _ => TypePrompt(
      label: 'Recall test',
      lead: "You're about to say this. Which word you learned says it better?",
      body: '"${w.insteadOf[(variant - 2) % w.insteadOf.length]}"',
      target: w.word,
      detail: w.example,
      hint: false,
    ),
  };

  /// Fill in [Word.cloze].
  factory TypePrompt.cloze(Word w) => TypePrompt(
    label: 'Fill in the blank',
    body: w.cloze,
    target: w.clozeAnswer,
    exact: true,
    detail: w.cloze.replaceFirst('___', w.clozeAnswer),
  );

  /// Produce the word from its definition.
  factory TypePrompt.recall(Word w) => TypePrompt(
    label: 'Recall the word',
    lead: 'Which word means:',
    body: w.definition,
    note: '(${w.partOfSpeech})',
    target: w.word,
    detail: w.example,
  );

  /// Produce the word that upgrades one of its plain alternatives.
  factory TypePrompt.swap(Word w, int variant) => TypePrompt(
    label: 'Upgrade the phrase',
    lead: 'Type a word you learned that could replace',
    body: '"${w.insteadOf[variant % w.insteadOf.length]}"',
    note: '(${w.partOfSpeech})',
    target: w.word,
    detail: w.example,
  );

  /// Fill the word back into a sentence the user wrote, if it contains it.
  static TypePrompt? own(Word w, String sentence) {
    final blank = blankWord(sentence, w);
    if (blank == null) return null;
    return TypePrompt(
      label: 'Your own sentence',
      lead: 'Fill in the word in a sentence you wrote:',
      body: blank.$1,
      target: blank.$2,
      exact: true,
      detail: sentence,
    );
  }

  final String label;
  final String? lead;
  final String body;
  final String? note;
  final String target;

  /// Whether only [target] counts, rather than any form of the word.
  final bool exact;

  /// Shown after answering: the full sentence or an example.
  final String detail;

  /// Whether the first letter can be revealed.
  final bool hint;
}

/// Typed recall. Typing (not picking) is what builds active recall.
class TypeStepView extends StatefulWidget {
  const TypeStepView({
    super.key,
    required this.word,
    required this.prompt,
    required this.onAnswered,
  });

  final Word word;
  final TypePrompt prompt;
  final OnAnswered onAnswered;

  @override
  State<TypeStepView> createState() => _TypeStepViewState();
}

class _TypeStepViewState extends State<TypeStepView> {
  final controller = TextEditingController();
  Verdict? verdict;
  bool hinted = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get target => widget.prompt.target;

  void check() {
    if (controller.text.trim().isEmpty) return;
    setState(
      () => verdict = checkTyped(
        controller.text,
        widget.word,
        exact: widget.prompt.exact ? target : null,
      ),
    );
  }

  void giveUp() => setState(() => verdict = Verdict.wrong);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final prompt = widget.prompt;
    final v = verdict;
    return _Scaffold(
      label: prompt.label,
      bottom: v == null
          ? Row(
              children: [
                TextButton(
                  onPressed: giveUp,
                  child: const Text("I don't know"),
                ),
                const Spacer(),
                FilledButton(onPressed: check, child: const Text('Check')),
              ],
            )
          : FeedbackPanel(
              passed: v.passed,
              title: switch (v) {
                Verdict.correct => 'Correct!',
                Verdict.closeSpelling => 'Almost! Spelled "$target".',
                Verdict.wrongForm => 'Right word. Here it\'s "$target".',
                Verdict.wrong => 'The answer is "$target".',
              },
              detail: prompt.detail,
              onContinue: () => widget.onAnswered(v.passed),
            ),
      children: [
        if (prompt.lead != null) ...[
          Text(prompt.lead!, style: text.titleMedium),
          const SizedBox(height: 8),
        ],
        Text(
          prompt.body,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (prompt.note != null) ...[
          const SizedBox(height: 8),
          Text(
            prompt.note!,
            style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: controller,
          enabled: v == null,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => check(),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type the word',
          ),
        ),
        const SizedBox(height: 8),
        if (v == null && prompt.hint)
          Align(
            alignment: Alignment.centerLeft,
            child: hinted
                ? Text(
                    'Starts with "${target[0]}", ${target.length} letters',
                    style: text.bodyMedium,
                  )
                : TextButton.icon(
                    onPressed: () => setState(() => hinted = true),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Hint'),
                  ),
          ),
      ],
    );
  }
}

/// Match several words to their meanings by tapping pairs.
class MatchStepView extends StatefulWidget {
  const MatchStepView({
    super.key,
    required this.words,
    required this.onAnswered,
    this.seed = 0,
  });

  final List<Word> words;
  final OnAnswered onAnswered;
  final int seed;

  @override
  State<MatchStepView> createState() => _MatchStepViewState();
}

class _MatchStepViewState extends State<MatchStepView> {
  late final List<Word> definitions = [...widget.words]
    ..shuffle(Random(widget.seed));
  final Set<String> matched = {};
  String? selected;
  String? wrongPair;
  int mistakes = 0;

  void tapDefinition(Word d) {
    final s = selected;
    if (s == null || matched.contains(d.id)) return;
    setState(() {
      if (s == d.id) {
        matched.add(d.id);
        wrongPair = null;
      } else {
        mistakes++;
        wrongPair = d.id;
      }
      selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final done = matched.length == widget.words.length;
    return _Scaffold(
      label: 'Match them up',
      bottom: done
          ? FeedbackPanel(
              passed: mistakes == 0,
              title: mistakes == 0
                  ? 'Perfect match!'
                  : 'All matched, with $mistakes slip${mistakes == 1 ? '' : 's'}.',
              onContinue: () => widget.onAnswered(mistakes == 0),
            )
          : null,
      children: [
        Text('Tap a word, then its meaning.', style: text.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in widget.words)
              ChoiceChip(
                label: Text(w.word, style: const TextStyle(fontSize: 16)),
                selected: selected == w.id,
                onSelected: matched.contains(w.id)
                    ? null
                    : (_) => setState(() => selected = w.id),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final d in definitions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(14),
                disabledForegroundColor: scheme.onSurface,
                backgroundColor: matched.contains(d.id)
                    ? scheme.primaryContainer
                    : wrongPair == d.id
                    ? scheme.errorContainer
                    : null,
              ),
              onPressed: matched.contains(d.id) ? null : () => tapDefinition(d),
              child: Text(
                matched.contains(d.id)
                    ? '${d.word}: ${d.definition}'
                    : d.definition,
              ),
            ),
          ),
      ],
    );
  }
}

/// The step that matters most: using the word in a sentence of your own,
/// under a challenge that changes each time, then checking it is right.
class SentenceStepView extends StatefulWidget {
  const SentenceStepView({
    super.key,
    required this.word,
    required this.challenge,
    required this.onAnswered,
    this.earlierSentences = const [],
    this.grader,
    this.onEnableAi,
  });

  final Word word;
  final SentenceChallenge challenge;

  /// Opens settings to add an API key, shown when there is no [grader].
  final VoidCallback? onEnableAi;
  final OnAnswered onAnswered;

  /// Sentences already written with this word, which must not be repeated.
  final List<String> earlierSentences;

  /// Checks meaning with Claude when set; otherwise the user self-checks.
  final SentenceGrader? grader;

  @override
  State<SentenceStepView> createState() => _SentenceStepViewState();
}

enum _Phase { writing, checking, selfCheck, done }

class _SentenceStepViewState extends State<SentenceStepView> {
  final controller = TextEditingController();
  _Phase phase = _Phase.writing;
  String? error;
  String? note;
  bool passed = false;
  String title = '';
  String? detail;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get sentence => controller.text.trim();

  String? localProblem(String s) {
    final w = widget.word;
    if (!sentenceUsesWord(s, w)) {
      return 'Use "${w.word}" (or a form of it) in your sentence.';
    }
    if (wordCount(s) < 5) return 'Make it a full sentence, at least 5 words.';
    if (similarity(s, w.example) >= 0.6) {
      return 'That is too close to the example. Make it your own.';
    }
    final repeat = tooSimilarTo(s, widget.earlierSentences);
    if (repeat != null) {
      return 'Too close to one you already wrote: "$repeat". Try a new idea.';
    }
    return widget.challenge.check?.call(s);
  }

  Future<void> submit() async {
    final problem = localProblem(sentence);
    if (problem != null) {
      setState(() => error = problem);
      return;
    }
    final grader = widget.grader;
    if (grader == null) {
      setState(() {
        error = null;
        phase = _Phase.selfCheck;
      });
      return;
    }
    setState(() {
      error = null;
      phase = _Phase.checking;
    });
    try {
      final r = await grader.grade(widget.word, widget.challenge, sentence);
      if (!mounted) return;
      final polished = r.betterSentence.trim() != sentence;
      finish(
        r.passed,
        switch (r.verdict) {
          UsageVerdict.correct => 'Nice. That works.',
          UsageVerdict.almost => 'Almost. Right meaning.',
          UsageVerdict.incorrect => 'Not quite. This word will come back.',
        },
        [
          r.feedback,
          if (polished)
            '${r.passed ? 'Even smoother' : 'Better'}: "${r.betterSentence}"',
        ].join('\n\n'),
      );
    } on GradeException catch (e) {
      if (!mounted) return;
      setState(() {
        note = '${e.message} Check it yourself this time.';
        phase = _Phase.selfCheck;
      });
    }
  }

  void finish(bool ok, String t, String? d) => setState(() {
    passed = ok;
    title = t;
    detail = d;
    phase = _Phase.done;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final w = widget.word;
    return _Scaffold(
      label: 'Use it yourself',
      bottom: switch (phase) {
        _Phase.writing => Row(
          children: [
            TextButton(
              onPressed: () => finish(
                false,
                'Here is one to borrow. You will get this again.',
                w.example,
              ),
              child: const Text("I'm stuck"),
            ),
            const Spacer(),
            FilledButton(onPressed: submit, child: const Text('Check')),
          ],
        ),
        _Phase.checking => const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Checking your sentence…'),
          ],
        ),
        _Phase.selfCheck => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Does your sentence use "${w.word}" to mean: ${w.definition}?',
              style: text.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => finish(
                      false,
                      'Good catch. Compare it with this one.',
                      w.example,
                    ),
                    child: const Text('Not quite'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => finish(
                      true,
                      'Saved to your notes.',
                      'Now say it out loud. Can you use it for real today?',
                    ),
                    child: const Text('Yes, it fits'),
                  ),
                ),
              ],
            ),
          ],
        ),
        _Phase.done => FeedbackPanel(
          passed: passed,
          title: title,
          detail: detail,
          onContinue: () => widget.onAnswered(
            passed,
            sentence: passed ? sentence : null,
            challengeId: passed ? widget.challenge.id : null,
          ),
        ),
      },
      children: [
        Text('Write a sentence with', style: text.titleMedium),
        Text(
          w.word,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(w.definition, style: text.bodyLarge),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.challenge.prompt,
                  style: text.titleSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: phase == _Phase.writing,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Your sentence…',
            errorText: error,
            errorMaxLines: 3,
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 8),
          Text(note!, style: text.bodySmall),
        ],
        if (widget.grader == null &&
            widget.onEnableAi != null &&
            phase == _Phase.writing)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onEnableAi,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Turn on AI checking'),
            ),
          ),
        if (widget.grader != null && phase == _Phase.writing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Claude will check this sentence', style: text.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}
