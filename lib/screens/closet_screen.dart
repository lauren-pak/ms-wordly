import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import '../services/rewards.dart';
import '../widgets/mascot.dart';
import 'achievements_screen.dart';

/// Spend points on accessories and dress up the mascot.
class ClosetScreen extends StatelessWidget {
  const ClosetScreen({super.key, required this.store});

  final ProgressStore store;

  Future<void> rename(BuildContext context) async {
    final controller = TextEditingController(text: store.mascotName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Name your bunny'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) await store.renameMascot(name);
  }

  Future<void> tapItem(BuildContext context, Accessory a) async {
    if (store.owned.contains(a.id)) {
      await store.toggleEquip(a);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    if (store.points < a.price) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'You need ${a.price - store.points} more points for the ${a.name.toLowerCase()}.',
          ),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Buy the ${a.name.toLowerCase()}?'),
        content: Mascot(size: 160, equipped: {...store.equipped, a.slot: a.id}),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Buy for ${a.price} ⭐'),
          ),
        ],
      ),
    );
    if (ok == true) await store.buy(a);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Closet'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text('⭐ ${store.points}', style: text.titleLarge),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(child: Mascot(size: 220, equipped: store.equipped)),
              Center(
                child: TextButton.icon(
                  onPressed: () => rename(context),
                  icon: const Icon(Icons.edit, size: 18),
                  label: Text(store.mascotName, style: text.titleLarge),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AchievementsScreen(store: store),
                    ),
                  ),
                  child: Text(
                    'Achievements: ${store.unlocked.length} of ${achievements.length}',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap an item to buy it, then tap again to put it on or take it off.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
                children: [
                  for (final a in accessories)
                    _ItemTile(
                      accessory: a,
                      owned: store.owned.contains(a.id),
                      wearing: store.equipped[a.slot] == a.id,
                      affordable: store.points >= a.price,
                      onTap: () => tapItem(context, a),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How to earn ⭐', style: text.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '• Daily session: ${dailyPoints(1)} points, up to '
                        '${dailyPoints(10)} as your streak grows\n'
                        '• Learning extra words: $bonusRoundPoints\n'
                        '• Extra practice round: $practicePoints\n'
                        '• Using a word in real life: $usedInLifePoints\n'
                        '• Achievements: 20 to 300 each',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.accessory,
    required this.owned,
    required this.wearing,
    required this.affordable,
    required this.onTap,
  });

  final Accessory accessory;
  final bool owned;
  final bool wearing;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: wearing ? scheme.primaryContainer : scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: wearing ? scheme.primary : scheme.outlineVariant,
          width: wearing ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: Opacity(
                  opacity: owned || affordable ? 1 : 0.55,
                  child: FittedBox(
                    child: Mascot(
                      size: 100,
                      equipped: {accessory.slot: accessory.id},
                    ),
                  ),
                ),
              ),
              Text(
                accessory.name,
                style: text.labelMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                wearing
                    ? 'Wearing'
                    : owned
                    ? 'Owned'
                    : '⭐ ${accessory.price}',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: owned ? scheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
