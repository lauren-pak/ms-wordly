import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import '../widgets/exercises.dart';

class WordsScreen extends StatelessWidget {
  const WordsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final words = store.learnedWords;
        return Scaffold(
          appBar: AppBar(title: const Text('My words')),
          body: words.isEmpty
              ? const Center(
                  child: Text('Finish today\'s session to see words here.'),
                )
              : ListView.builder(
                  itemCount: words.length,
                  itemBuilder: (context, i) {
                    final p = words[i];
                    return ListTile(
                      title: Text(
                        p.word.word,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        p.word.definition,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _LevelBadge(progress: p),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WordDetailScreen(store: store, id: p.id),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.progress});

  final WordProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      visualDensity: VisualDensity.compact,
      backgroundColor: progress.mastered
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      label: Text(
        progress.mastered ? 'Active' : 'Level ${progress.level}/$masteredLevel',
      ),
    );
  }
}

class WordDetailScreen extends StatelessWidget {
  const WordDetailScreen({super.key, required this.store, required this.id});

  final ProgressStore store;
  final String id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.progress[id]!;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              WordCard(word: p.word),
              const SizedBox(height: 24),
              Text('Your sentences', style: text.titleMedium),
              const SizedBox(height: 8),
              if (p.sentences.isEmpty) const Text('None yet.'),
              for (final s in p.sentences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $s', style: text.bodyLarge),
                ),
              const SizedBox(height: 16),
              Text(
                p.mastered
                    ? 'Part of your active vocabulary. Next check-in: ${p.due}'
                    : 'Level ${p.level} of $masteredLevel. Next review: ${p.due}',
                style: text.bodyMedium,
              ),
              Text(
                'Used in real life: ${p.usedInLife} times',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: store.usedToday(id)
                    ? null
                    : () => store.markUsedInLife(id),
                icon: const Icon(Icons.record_voice_over),
                label: Text(
                  store.usedToday(id) ? 'Logged for today' : 'I used it today',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
