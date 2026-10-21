import 'package:flutter/material.dart';

import '../models/word.dart';
import '../services/progress_store.dart';

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.store, required this.words});

  final ProgressStore store;
  final List<Word> words;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final streak = store.currentStreak;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Center(child: Text('🔥', style: TextStyle(fontSize: 88))),
            Center(
              child: Text(
                '$streak day streak',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                streak == store.bestStreak && streak > 1
                    ? 'Your best streak yet!'
                    : 'Done for today. See you tomorrow.',
                style: text.titleMedium,
              ),
            ),
            if (words.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text("Today's challenge", style: text.titleLarge),
              const SizedBox(height: 4),
              const Text(
                'Use each word once in real life today: a message, an email, '
                'a conversation. Tap it on the home screen when you do.',
              ),
              const SizedBox(height: 12),
              for (final w in words)
                Card(
                  child: ListTile(
                    title: Text(
                      w.word,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(w.definition),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back home'),
            ),
          ],
        ),
      ),
    );
  }
}
