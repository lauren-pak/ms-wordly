import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/progress_store.dart';
import '../services/session_builder.dart';
import '../widgets/exercises.dart';
import 'done_screen.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final List<Word> newWords;
  late final List<SessionStep> queue;
  late final int plannedSteps;
  final Set<String> missed = {};
  final Map<String, List<String>> sentences = {};
  final Set<String> reviewIds = {};
  int index = 0;
  bool finishing = false;

  @override
  void initState() {
    super.initState();
    newWords = widget.store.todaysNewWords;
    final reviews = widget.store.dueReviews;
    reviewIds.addAll(reviews.map((r) => r.id));
    queue = buildSession(newWords, reviews);
    plannedSteps = queue.length;
    // Nothing due and no new words left: checking in still counts the day.
    if (queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => finish());
    }
  }

  void advance(bool passed, {String? sentence}) {
    final step = queue[index];
    if (!passed && step.kind != StepKind.learn) {
      missed.add(step.word.id);
      // Missed exercises come back once at the end of the session.
      if (!step.isRetry) queue.add(step.retry());
    }
    if (sentence != null) {
      sentences.putIfAbsent(step.word.id, () => []).add(sentence);
    }
    if (index + 1 >= queue.length) {
      finish();
    } else {
      setState(() => index++);
    }
  }

  Future<void> finish() async {
    setState(() => finishing = true);
    await widget.store.completeSession(
      newWordResults: {for (final w in newWords) w.id: !missed.contains(w.id)},
      reviewResults: {for (final id in reviewIds) id: !missed.contains(id)},
      sentences: sentences,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DoneScreen(store: widget.store, words: newWords),
      ),
    );
  }

  Future<bool> confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave today\'s session?'),
        content: const Text(
          'Your progress in this session will be lost and your streak '
          'only counts finished sessions.',
        ),
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
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (queue.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final step = queue[index];
    final key = ValueKey(index);
    final Widget body = finishing
        ? const Center(child: CircularProgressIndicator())
        : switch (step.kind) {
            StepKind.learn => LearnStepView(
              key: key,
              word: step.word,
              onDone: () => advance(true),
            ),
            StepKind.choose => ChooseStepView(
              key: key,
              word: step.word,
              options: step.options,
              onAnswered: advance,
            ),
            StepKind.cloze => TypeStepView(
              key: key,
              word: step.word,
              fromDefinition: false,
              onAnswered: advance,
            ),
            StepKind.recall => TypeStepView(
              key: key,
              word: step.word,
              fromDefinition: true,
              onAnswered: advance,
            ),
            StepKind.sentence => SentenceStepView(
              key: key,
              word: step.word,
              onAnswered: advance,
            ),
          };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await confirmQuit()) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: LinearProgressIndicator(
            value: (index / plannedSteps).clamp(0.0, 1.0),
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
          ),
          actions: [
            if (step.isReview)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Chip(label: Text('Review')),
              ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}
