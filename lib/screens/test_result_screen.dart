import 'package:flutter/material.dart';

import '../data/word_bank.dart';
import '../services/progress_store.dart';
import '../widgets/mascot.dart';

/// The score of a recall test, with the words that need more work.
class TestResultScreen extends StatelessWidget {
  const TestResultScreen({
    super.key,
    required this.store,
    required this.results,
  });

  final ProgressStore store;

  /// Word id to whether it was recalled.
  final Map<String, bool> results;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final right = results.values.where((ok) => ok).length;
    final total = results.length;
    final missed = [
      for (final e in results.entries)
        if (!e.value) wordsById[e.key]!,
    ];
    final reward = store.lastReward;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: Mascot(size: 160, equipped: store.equipped)),
            Center(
              child: Text(
                '$right / $total recalled',
                style: text.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                right == total
                    ? 'Every word came straight to mind!'
                    : right * 2 >= total
                    ? 'Nice work. The rest come back tomorrow.'
                    : 'These need more practice. They come back tomorrow.',
                textAlign: TextAlign.center,
                style: text.titleMedium,
              ),
            ),
            if (reward != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Chip(
                  avatar: const Text('⭐'),
                  label: Text(
                    '+${reward.points} points',
                    style: text.titleSmall,
                  ),
                ),
              ),
              for (final a in reward.unlocked)
                Card(
                  color: scheme.tertiaryContainer,
                  child: ListTile(
                    leading: Text(
                      a.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text('Achievement: ${a.title}'),
                    subtitle: Text('${a.description} · +${a.points} ⭐'),
                  ),
                ),
            ],
            if (missed.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Words to work on', style: text.titleLarge),
              const SizedBox(height: 8),
              for (final w in missed)
                Card(
                  child: ListTile(
                    title: Text(
                      w.word,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${w.definition}\n"${w.example}"'),
                    isThreeLine: true,
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
