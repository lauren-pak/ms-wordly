import 'package:flutter/material.dart';

import '../data/word_bank.dart';
import '../models/word.dart';
import '../services/progress_store.dart';

String difficultyLabel(Difficulty? d) => d?.label ?? 'Mix';

/// Radio options for the difficulty of new words.
class DifficultyOptions extends StatelessWidget {
  const DifficultyOptions({super.key, required this.store, this.onChanged});

  final ProgressStore store;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <Difficulty?>[...Difficulty.values, null];
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => RadioGroup<Difficulty?>(
        groupValue: store.difficulty,
        onChanged: (d) async {
          await store.setDifficulty(d);
          onChanged?.call();
        },
        child: Column(
          children: [
            for (final d in options)
              RadioListTile<Difficulty?>(
                value: d,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${difficultyLabel(d)} (${wordsAt(d).length} words)',
                ),
                subtitle: Text(d?.description ?? 'A bit of everything'),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDifficultyPicker(BuildContext context, ProgressStore store) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Word difficulty', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                store.doneToday
                    ? 'Applies to new words from now on.'
                    : "Today's words will change to match.",
              ),
              DifficultyOptions(
                store: store,
                onChanged: () => Navigator.of(c).pop(),
              ),
            ],
          ),
        ),
      ),
    );
