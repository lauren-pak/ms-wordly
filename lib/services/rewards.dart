import 'progress_store.dart';

class Achievement {
  const Achievement(
    this.id,
    this.emoji,
    this.title,
    this.description,
    this.points,
    this.earned,
  );

  final String id;
  final String emoji;
  final String title;
  final String description;
  final int points;
  final bool Function(ProgressStore s) earned;
}

final List<Achievement> achievements = [
  Achievement(
    'first_session',
    '🌱',
    'First steps',
    'Finish your first daily session',
    20,
    (s) => s.sessionsCompleted >= 1,
  ),
  Achievement(
    'streak_3',
    '🔥',
    'Warming up',
    'Reach a 3-day streak',
    30,
    (s) => s.bestStreak >= 3,
  ),
  Achievement(
    'streak_7',
    '📅',
    'One whole week',
    'Reach a 7-day streak',
    75,
    (s) => s.bestStreak >= 7,
  ),
  Achievement(
    'streak_14',
    '💪',
    'Two weeks strong',
    'Reach a 14-day streak',
    150,
    (s) => s.bestStreak >= 14,
  ),
  Achievement(
    'streak_30',
    '🏆',
    'Word habit',
    'Reach a 30-day streak',
    300,
    (s) => s.bestStreak >= 30,
  ),
  Achievement(
    'words_10',
    '🧺',
    'Collector',
    'Learn 10 words',
    30,
    (s) => s.progress.length >= 10,
  ),
  Achievement(
    'words_30',
    '📚',
    'Bookworm',
    'Learn 30 words',
    80,
    (s) => s.progress.length >= 30,
  ),
  Achievement(
    'words_60',
    '🦉',
    'Walking thesaurus',
    'Learn 60 words',
    150,
    (s) => s.progress.length >= 60,
  ),
  Achievement(
    'active_1',
    '✨',
    'It stuck!',
    'Get your first word into your active vocab',
    50,
    (s) => s.masteredCount >= 1,
  ),
  Achievement(
    'active_10',
    '💬',
    'Silver tongue',
    'Have 10 words in your active vocab',
    150,
    (s) => s.masteredCount >= 10,
  ),
  Achievement(
    'used_1',
    '🗣️',
    'Out in the wild',
    'Use a new word in real life',
    20,
    (s) => s.usedInLifeCount >= 1,
  ),
  Achievement(
    'used_10',
    '😎',
    'Smooth talker',
    'Use your words in real life 10 times',
    80,
    (s) => s.usedInLifeCount >= 10,
  ),
  Achievement(
    'sentences_10',
    '✍️',
    'Wordsmith',
    'Write 10 sentences',
    40,
    (s) => s.sentenceCount >= 10,
  ),
  Achievement(
    'sentences_50',
    '🖋️',
    'Author',
    'Write 50 sentences',
    120,
    (s) => s.sentenceCount >= 50,
  ),
  Achievement(
    'perfect',
    '💯',
    'Flawless',
    'Finish a session with no misses',
    25,
    (s) => s.perfectSessions >= 1,
  ),
  Achievement(
    'practice_5',
    '🏋️',
    'Overachiever',
    'Do 5 extra practice rounds',
    50,
    (s) => s.practiceRounds >= 5,
  ),
  Achievement(
    'more_words',
    '🍪',
    'Hungry for more',
    'Learn extra words after your daily session',
    20,
    (s) => s.bonusRounds >= 1,
  ),
];

/// Points for finishing the day's first session: more as the streak grows.
int dailyPoints(int streak) => 10 + 2 * (streak < 10 ? streak : 10);
const int bonusRoundPoints = 5;
const int practicePoints = 3;
const int usedInLifePoints = 2;

/// What one action earned, shown to celebrate it.
class Reward {
  const Reward(this.points, this.unlocked);
  final int points;
  final List<Achievement> unlocked;
}

enum Slot { head, face, neck, held }

class Accessory {
  const Accessory(this.id, this.name, this.slot, this.price);
  final String id;
  final String name;
  final Slot slot;
  final int price;
}

const List<Accessory> accessories = [
  Accessory('bow', 'Pink bow', Slot.head, 40),
  Accessory('party_hat', 'Party hat', Slot.head, 80),
  Accessory('beanie', 'Strawberry beanie', Slot.head, 120),
  Accessory('flowers', 'Flower crown', Slot.head, 150),
  Accessory('crown', 'Tiny crown', Slot.head, 300),
  Accessory('stars', 'Star stickers', Slot.face, 30),
  Accessory('glasses', 'Round glasses', Slot.face, 60),
  Accessory('hearts', 'Heart sunnies', Slot.face, 100),
  Accessory('bowtie', 'Bow tie', Slot.neck, 50),
  Accessory('scarf', 'Cozy scarf', Slot.neck, 70),
  Accessory('pearls', 'Pearl necklace', Slot.neck, 140),
  Accessory('carrot', 'Carrot snack', Slot.held, 40),
  Accessory('coffee', 'Tiny latte', Slot.held, 50),
  Accessory('balloon', 'Balloon', Slot.held, 60),
  Accessory('book', 'Mini dictionary', Slot.held, 90),
];

final Map<String, Accessory> accessoriesById = {
  for (final a in accessories) a.id: a,
};
