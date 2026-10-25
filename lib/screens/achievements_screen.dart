import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import '../services/rewards.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final a in achievements)
            if (store.unlocked.contains(a.id))
              ListTile(
                leading: Text(a.emoji, style: const TextStyle(fontSize: 30)),
                title: Text(
                  a.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(a.description),
                trailing: Chip(
                  backgroundColor: scheme.primaryContainer,
                  label: Text('+${a.points} ⭐'),
                ),
              )
            else
              ListTile(
                leading: Opacity(
                  opacity: 0.35,
                  child: Text(a.emoji, style: const TextStyle(fontSize: 30)),
                ),
                title: Text(a.title),
                subtitle: Text(a.description),
                trailing: Text(
                  '${a.points} ⭐',
                  style: TextStyle(color: scheme.outline),
                ),
              ),
        ],
      ),
    );
  }
}
