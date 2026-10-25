import 'dart:math';

import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/progress_store.dart';
import '../services/sentence_grader.dart';
import '../services/use_it_test.dart';
import 'settings_screen.dart';
import 'test_result_screen.dart';

/// Learned words a reply must use before it can be checked.
const int minWordsPerReply = 2;

/// Real-life prompts that name no word: the user decides which of their
/// learned words fit, writes a reply, and each word they used is checked.
class UseItTestScreen extends StatefulWidget {
  const UseItTestScreen({super.key, required this.store, this.grader});

  final ProgressStore store;

  /// Overrides the Claude grader built from the saved API key (for tests).
  final ResponseGrader? grader;

  @override
  State<UseItTestScreen> createState() => _UseItTestScreenState();
}

enum _Phase { writing, checking, review, selfCheck }

class _UseItTestScreenState extends State<UseItTestScreen> {
  final controller = TextEditingController();
  final rng = Random();
  late final List<String> unused = pickScenarios(count: 1000, random: rng);
  late final List<Word> learned = [
    for (final p in store.progress.values) p.word,
  ];
  late ResponseGrader? grader = widget.grader ?? _savedGrader();

  late String scenario = unused.removeAt(0);
  int round = 0;
  _Phase phase = _Phase.writing;
  List<Word> spotted = [];
  List<Word>? ideas;
  ResponseGrade? grade;
  String? error;
  final Map<String, bool> selfMarks = {};
  final Map<String, bool> results = {};
  final Map<String, List<String>> sentences = {};
  bool finishing = false;

  ProgressStore get store => widget.store;

  ResponseGrader? _savedGrader() {
    final key = store.apiKey;
    return key == null ? null : ClaudeSentenceGrader(key);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> enableAi() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SettingsScreen(store: store)));
    if (mounted) setState(() => grader = widget.grader ?? _savedGrader());
  }

  void newPrompt() => setState(() {
    unused.add(scenario);
    scenario = unused.removeAt(0);
  });

  void showIdeas() => setState(() {
    final pool = [...learned]..shuffle(rng);
    ideas = pool.take(5).toList();
  });

  Future<void> check() async {
    final g = grader;
    if (g == null) {
      setState(() => phase = _Phase.selfCheck);
      return;
    }
    setState(() {
      phase = _Phase.checking;
      error = null;
    });
    try {
      final r = await g.gradeResponse(scenario, controller.text, spotted);
      if (mounted) {
        setState(() {
          grade = r;
          phase = _Phase.review;
        });
      }
    } on GradeException catch (e) {
      if (mounted) {
        setState(() {
          error = '${e.message} Check your own words instead.';
          phase = _Phase.selfCheck;
        });
      }
    }
  }

  void next() {
    final verdicts = phase == _Phase.review
        ? {for (final g in grade!.words) g.word.id: g.passed}
        : selfMarks;
    for (final w in spotted) {
      final ok = verdicts[w.id] ?? false;
      results[w.id] = (results[w.id] ?? true) && ok;
      sentences
          .putIfAbsent(w.id, () => [])
          .add(sentenceWith(controller.text, w));
    }
    if (round + 1 >= useItRounds) {
      finish();
      return;
    }
    setState(() {
      round++;
      scenario = unused.removeAt(0);
      controller.clear();
      spotted = [];
      ideas = null;
      grade = null;
      error = null;
      selfMarks.clear();
      phase = _Phase.writing;
    });
  }

  Future<void> finish() async {
    setState(() => finishing = true);
    await store.completeUseItTest(results: results, sentences: sentences);
    if (!mounted) return;
    final right = results.values.where((ok) => ok).length;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TestResultScreen(
          store: store,
          results: results,
          headline: '$right ${right == 1 ? 'word' : 'words'} used well',
          message: right == results.length
              ? 'You reached for your words on your own. That is active '
                    'vocabulary!'
              : 'The ones that slipped come back tomorrow.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: phase == _Phase.writing && controller.text.isEmpty && round == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Leave this test?'),
            content: const Text('Your answers so far will be lost.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Keep going'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave ?? false) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: LinearProgressIndicator(
            value: round / useItRounds,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(label: Text('Use it ${round + 1}/$useItRounds')),
            ),
          ],
        ),
        body: SafeArea(
          child: finishing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Text(
                            'USE-IT TEST',
                            style: text.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            scenario,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...switch (phase) {
                            _Phase.writing => _writing(context),
                            _Phase.checking => [
                              Text(controller.text, style: text.bodyLarge),
                              const SizedBox(height: 24),
                              const Center(child: CircularProgressIndicator()),
                              const SizedBox(height: 8),
                              const Center(
                                child: Text('Claude is reading your reply…'),
                              ),
                            ],
                            _Phase.review => _review(context),
                            _Phase.selfCheck => _selfCheck(context),
                          },
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: _bottom(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _bottom() => switch (phase) {
    _Phase.writing => Row(
      children: [
        TextButton(onPressed: newPrompt, child: const Text('New prompt')),
        const Spacer(),
        FilledButton(
          onPressed: spotted.length >= minWordsPerReply ? check : null,
          child: const Text('Check'),
        ),
      ],
    ),
    _Phase.checking => const SizedBox.shrink(),
    _Phase.review => SizedBox(
      width: double.infinity,
      child: FilledButton(onPressed: next, child: const Text('Continue')),
    ),
    _Phase.selfCheck => SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: spotted.every((w) => selfMarks.containsKey(w.id))
            ? next
            : null,
        child: const Text('Continue'),
      ),
    ),
  };

  List<Widget> _writing(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ideas = this.ideas;
    return [
      Text(
        'Reply in a few sentences. Work in at least $minWordsPerReply of your '
        'learned words. You choose which.',
        style: text.bodyLarge,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: controller,
        autofocus: true,
        minLines: 4,
        maxLines: 10,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (v) => setState(() => spotted = wordsUsedIn(v, learned)),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: 'Write your reply',
        ),
      ),
      const SizedBox(height: 12),
      if (spotted.isEmpty)
        Text('No learned words spotted yet.', style: text.bodyMedium)
      else
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Spotted:', style: text.bodyMedium),
            for (final w in spotted)
              Chip(
                avatar: const Icon(Icons.check, size: 16),
                label: Text(w.word),
              ),
          ],
        ),
      const SizedBox(height: 8),
      if (ideas == null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: showIdeas,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Stuck? Show a few of my words'),
          ),
        )
      else
        Text(
          'A few of your words: ${ideas.map((w) => w.word).join(', ')}. '
          'Not all of them will fit.',
          style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      if (grader == null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: enableAi,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Turn on AI checking'),
          ),
        ),
    ];
  }

  List<Widget> _review(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final g = grade!;
    return [
      Text(controller.text, style: text.bodyLarge),
      const SizedBox(height: 16),
      for (final w in g.words)
        Card(
          color: w.passed ? scheme.primaryContainer : scheme.errorContainer,
          child: ListTile(
            leading: Text(switch (w.verdict) {
              UsageVerdict.correct => '✅',
              UsageVerdict.almost => '👌',
              UsageVerdict.incorrect => '❌',
            }, style: const TextStyle(fontSize: 22)),
            title: Text(
              w.word.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(w.feedback),
          ),
        ),
      const SizedBox(height: 12),
      Text(g.feedback, style: text.bodyMedium),
      const SizedBox(height: 12),
      Text('Polished', style: text.titleSmall),
      const SizedBox(height: 4),
      Text(
        g.polished,
        style: text.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
      ),
    ];
  }

  List<Widget> _selfCheck(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      Text(controller.text, style: text.bodyLarge),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(
          error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      const SizedBox(height: 16),
      Text(
        'Compare each word with its meaning. Did you use it right?',
        style: text.titleMedium,
      ),
      const SizedBox(height: 8),
      for (final w in spotted)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${w.word} (${w.partOfSpeech})',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(w.definition),
                const SizedBox(height: 4),
                Text(
                  w.example,
                  style: text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  emptySelectionAllowed: true,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Used it right')),
                    ButtonSegment(value: false, label: Text('Not quite')),
                  ],
                  selected: {?selfMarks[w.id]},
                  onSelectionChanged: (v) => setState(() {
                    if (v.isEmpty) {
                      selfMarks.remove(w.id);
                    } else {
                      selfMarks[w.id] = v.first;
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}
