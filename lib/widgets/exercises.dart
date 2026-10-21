import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/answer_check.dart';

typedef OnAnswered = void Function(bool passed, {String? sentence});

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

/// Typed recall: either fill in a sentence or produce the word from its
/// definition. Typing (not picking) is what builds active recall.
class TypeStepView extends StatefulWidget {
  const TypeStepView({
    super.key,
    required this.word,
    required this.fromDefinition,
    required this.onAnswered,
  });

  final Word word;
  final bool fromDefinition;
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

  String get target =>
      widget.fromDefinition ? widget.word.word : widget.word.clozeAnswer;

  void check() {
    if (controller.text.trim().isEmpty) return;
    setState(
      () => verdict = checkTyped(
        controller.text,
        widget.word,
        exact: widget.fromDefinition ? null : widget.word.clozeAnswer,
      ),
    );
  }

  void giveUp() => setState(() => verdict = Verdict.wrong);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = verdict;
    return _Scaffold(
      label: widget.fromDefinition ? 'Recall the word' : 'Fill in the blank',
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
              detail: widget.fromDefinition
                  ? widget.word.example
                  : widget.word.cloze.replaceFirst('___', target),
              onContinue: () => widget.onAnswered(v.passed),
            ),
      children: [
        if (widget.fromDefinition) ...[
          Text('Which word means:', style: text.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.word.definition,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '(${widget.word.partOfSpeech})',
            style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ] else
          Text(
            widget.word.cloze,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
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
        if (v == null)
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

/// The step that matters most: using the word in a sentence of your own.
class SentenceStepView extends StatefulWidget {
  const SentenceStepView({
    super.key,
    required this.word,
    required this.onAnswered,
  });

  final Word word;
  final OnAnswered onAnswered;

  @override
  State<SentenceStepView> createState() => _SentenceStepViewState();
}

class _SentenceStepViewState extends State<SentenceStepView> {
  final controller = TextEditingController();
  String? error;
  bool? submitted;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final s = controller.text.trim();
    if (!sentenceUsesWord(s, widget.word)) {
      setState(
        () => error =
            'Use "${widget.word.word}" (or a form of it) in your sentence.',
      );
      return;
    }
    if (wordCount(s) < 5) {
      setState(() => error = 'Make it a full sentence, at least 5 words.');
      return;
    }
    setState(() {
      error = null;
      submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = submitted;
    return _Scaffold(
      label: 'Use it yourself',
      bottom: done == null
          ? Row(
              children: [
                TextButton(
                  onPressed: () => setState(() => submitted = false),
                  child: const Text("I'm stuck"),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: submit,
                  child: const Text('Save sentence'),
                ),
              ],
            )
          : FeedbackPanel(
              passed: done,
              title: done
                  ? 'Saved to your notes.'
                  : 'Here is one to borrow. You will get this again.',
              detail: done
                  ? 'Now say it out loud. Can you use it in a real conversation today?'
                  : widget.word.example,
              onContinue: () => widget.onAnswered(
                done,
                sentence: done ? controller.text.trim() : null,
              ),
            ),
      children: [
        Text('Write a sentence with', style: text.titleMedium),
        Text(
          widget.word.word,
          style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(widget.word.definition, style: text.bodyLarge),
        const SizedBox(height: 16),
        Text(
          'Make it about your own life: something you could actually say or '
          'write this week.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          enabled: done == null,
          minLines: 3,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: 'Your sentence…',
            errorText: error,
          ),
        ),
      ],
    );
  }
}
