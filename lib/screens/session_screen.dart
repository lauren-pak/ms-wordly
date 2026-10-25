import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/progress_store.dart';
import '../services/sentence_grader.dart';
import '../services/session_builder.dart';
import '../widgets/exercises.dart';
import 'done_screen.dart';

enum SessionMode {
  /// Today's words plus due reviews. Finishing it keeps the streak.
  daily,

  /// Three more new words after the daily session.
  moreWords,

  /// A few learned words, one exercise each, without moving the schedule.
  practice,
}

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.store,
    this.mode = SessionMode.daily,
    this.grader,
  });

  final ProgressStore store;
  final SessionMode mode;

  /// Overrides the Claude grader built from the saved API key (for tests).
  final SentenceGrader? grader;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late final List<Word> newWords;
  late final List<SessionStep> queue;
  late final int plannedSteps;
  late final SentenceGrader? grader;
  final Set<String> missed = {};
  final Map<String, List<String>> sentences = {};
  final Map<String, List<String>> challenges = {};
  final Set<String> reviewIds = {};
  int index = 0;
  bool finishing = false;

  ProgressStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final key = store.apiKey;
    grader = widget.grader ?? (key == null ? null : ClaudeSentenceGrader(key));
    switch (widget.mode) {
      case SessionMode.daily:
        newWords = store.todaysNewWords;
        final reviews = store.dueReviews;
        reviewIds.addAll(reviews.map((r) => r.id));
        queue = buildSession(newWords, reviews);
      case SessionMode.moreWords:
        newWords = store.nextNewWords();
        queue = buildSession(newWords, []);
      case SessionMode.practice:
        newWords = [];
        final words = store.practiceSet();
        reviewIds.addAll(words.map((r) => r.id));
        queue = buildPractice(words);
    }
    plannedSteps = queue.length;
    // Nothing due and no new words left: checking in still counts the day.
    if (queue.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => finish());
    }
  }

  void advance(bool passed, {String? sentence, String? challengeId}) {
    final step = queue[index];
    if (!passed && step.kind != StepKind.learn) {
      missed.add(step.word.id);
      // Missed exercises come back once at the end of the session.
      if (!step.isRetry) queue.add(step.retry());
    }
    if (sentence != null) {
      sentences.putIfAbsent(step.word.id, () => []).add(sentence);
    }
    if (challengeId != null) {
      challenges.putIfAbsent(step.word.id, () => []).add(challengeId);
    }
    if (index + 1 >= queue.length) {
      finish();
    } else {
      setState(() => index++);
    }
  }

  /// Sentences already written with [word], so new ones can't repeat them.
  List<String> earlierSentences(Word word) => [
    ...?store.progress[word.id]?.sentences,
    ...?sentences[word.id],
  ];

  Future<void> finish() async {
    setState(() => finishing = true);
    if (widget.mode == SessionMode.practice) {
      await store.completePractice(
        results: {for (final id in reviewIds) id: !missed.contains(id)},
        sentences: sentences,
        challenges: challenges,
      );
    } else {
      await store.completeSession(
        newWordResults: {
          for (final w in newWords) w.id: !missed.contains(w.id),
        },
        reviewResults: {for (final id in reviewIds) id: !missed.contains(id)},
        sentences: sentences,
        challenges: challenges,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DoneScreen(store: store, words: newWords),
      ),
    );
  }

  Future<bool> confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave this session?'),
        content: Text(
          widget.mode == SessionMode.daily && !store.doneToday
              ? 'Your progress in this session will be lost and your streak '
                    'only counts finished sessions.'
              : 'Your progress in this session will be lost.',
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
              challenge: step.challenge!,
              earlierSentences: earlierSentences(step.word),
              grader: grader,
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
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: Text(
                    widget.mode == SessionMode.practice ? 'Practice' : 'Review',
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(child: body),
      ),
    );
  }
}
