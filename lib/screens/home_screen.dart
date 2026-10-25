import 'package:flutter/material.dart';

import '../services/progress_store.dart';
import '../services/rewards.dart';
import '../widgets/difficulty_picker.dart';
import '../widgets/mascot.dart';
import 'closet_screen.dart';
import 'session_screen.dart';
import 'settings_screen.dart';
import 'use_it_test_screen.dart';
import 'words_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  ProgressStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back to the app on a new day should show the new day's plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  void startSession([SessionMode mode = SessionMode.daily]) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScreen(store: store, mode: mode),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text(
            'Ms Wordly',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                '🔥 ${store.currentStreak}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => SettingsScreen(store: store)),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _MascotCard(store: store),
            const SizedBox(height: 12),
            _StreakCard(store: store),
            const SizedBox(height: 12),
            if (store.doneToday) ...[
              _DoneTodayCard(store: store),
              const SizedBox(height: 12),
              _KeepGoingCard(store: store, onStart: startSession),
            ] else
              _TodayCard(store: store, onStart: startSession),
            if (store.progress.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MissionCard(store: store),
            ],
            if (store.progress.length >= 3) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.psychology_alt_outlined),
                  title: const Text('Recall test'),
                  subtitle: const Text(
                    'See a meaning or a situation, type the word. No hints.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => startSession(SessionMode.test),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.record_voice_over_outlined),
                  title: const Text('Use-it test'),
                  subtitle: const Text(
                    'Real-life prompts. You come up with which words to use.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UseItTestScreen(store: store),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _StatsRow(store: store),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('My words'),
                subtitle: Text('${store.progress.length} learned'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => WordsScreen(store: store)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = store.today;
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.currentStreak == 0
                  ? 'Start a streak today'
                  : '${store.currentStreak} day streak',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text('Best: ${store.bestStreak} days'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in days)
                  Column(
                    children: [
                      Text(
                        letters[parseDay(d).weekday - 1],
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: store.completedDays.contains(d)
                            ? scheme.primary
                            : scheme.surfaceContainerHighest,
                        child: store.completedDays.contains(d)
                            ? Icon(
                                Icons.local_fire_department,
                                size: 18,
                                color: scheme.onPrimary,
                              )
                            : null,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.store, required this.onStart});

  final ProgressStore store;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final newCount = store.todaysNewWords.length;
    final reviewCount = store.dueReviews.length;
    final parts = [
      if (newCount > 0) '$newCount new ${newCount == 1 ? 'word' : 'words'}',
      if (reviewCount > 0) '$reviewCount to review',
    ];
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Today's words",
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              parts.isEmpty
                  ? 'All caught up. Check in to keep your streak.'
                  : '${parts.join(' · ')} · about 5 minutes',
            ),
            const SizedBox(height: 8),
            ActionChip(
              avatar: const Icon(Icons.tune, size: 18),
              label: Text('Level: ${difficultyLabel(store.difficulty)}'),
              onPressed: () => showDifficultyPicker(context, store),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoneTodayCard extends StatelessWidget {
  const _DoneTodayCard({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    final words = store.learnedToday;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Done for today',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (words.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('New today: ${words.map((w) => w.word).join(', ')}'),
            ],
          ],
        ),
      ),
    );
  }
}

/// Three learned words to use for real today, confirmed in the evening.
class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.store});

  final ProgressStore store;

  Future<void> markUsed(BuildContext context, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final wasDone = store.missionDone;
    final reward = await store.markUsedInLife(id);
    if (reward == null) return;
    final parts = [
      if (!wasDone && store.missionDone) 'Mission complete!',
      '+${reward.points} ⭐',
      for (final a in reward.unlocked) '${a.emoji} ${a.title}',
    ];
    messenger.showSnackBar(SnackBar(content: Text(parts.join('  '))));
  }

  @override
  Widget build(BuildContext context) {
    final words = store.mission;
    final text = Theme.of(context).textTheme;
    final evening = store.now.hour >= 17;
    final usedCount = words.where((w) => store.usedToday(w.id)).length;
    return Card(
      color: store.missionDone
          ? Theme.of(context).colorScheme.tertiaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🎯 Use it today',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('$usedCount/${words.length}', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              store.missionDone
                  ? 'Mission complete! These words are becoming yours.'
                  : evening
                  ? 'How did it go? Tap each word you used today.'
                  : 'Use these in a real conversation, text, or email today. '
                        'Check back tonight and tap the ones you used. '
                        'All $missionSize earns +$missionPoints ⭐.',
            ),
            const SizedBox(height: 4),
            for (final w in words)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  w.word,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('Instead of "${w.insteadOf.first}"'),
                trailing: store.usedToday(w.id)
                    ? const Chip(label: Text('Used ✓'))
                    : OutlinedButton(
                        onPressed: () => markUsed(context, w.id),
                        child: const Text('I used it'),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    Widget stat(String value, String label) => Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        stat('${store.progress.length}', 'Learned'),
        stat('${store.masteredCount}', 'Active vocab'),
        stat('${store.usedInLifeCount}', 'Used for real'),
      ],
    );
  }
}

/// After the daily session: as much extra work as you like.
class _KeepGoingCard extends StatelessWidget {
  const _KeepGoingCard({required this.store, required this.onStart});

  final ProgressStore store;
  final void Function(SessionMode) onStart;

  @override
  Widget build(BuildContext context) {
    final more = store.nextNewWords().length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep going',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Text("Your streak is safe. Extra rounds are a bonus."),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: more == 0
                        ? null
                        : () => onStart(SessionMode.moreWords),
                    icon: const Icon(Icons.add),
                    label: Text(
                      more == 0 ? 'No new words' : 'Learn $more more',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: store.progress.isEmpty
                        ? null
                        : () => onStart(SessionMode.practice),
                    icon: const Icon(Icons.fitness_center),
                    label: const Text('Practice'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MascotCard extends StatelessWidget {
  const _MascotCard({required this.store});

  final ProgressStore store;

  String get line {
    final streak = store.currentStreak;
    if (store.doneToday) return 'We did it today! Want to keep going?';
    if (streak > 0) return "Let's keep our $streak-day streak going!";
    if (store.progress.isEmpty) {
      return "Hi, I'm ${store.mascotName}! Let's learn some words.";
    }
    return "I missed you! Ready for today's words?";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    void openCloset() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ClosetScreen(store: store)));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openCloset,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: Row(
            children: [
              Mascot(size: 120, equipped: store.equipped),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Text(line, style: text.bodyMedium),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text('⭐ ${store.points}', style: text.titleMedium),
                        const Spacer(),
                        FilledButton.tonal(
                          onPressed: openCloset,
                          child: const Text('Closet'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
