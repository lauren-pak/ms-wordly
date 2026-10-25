enum Difficulty {
  everyday('Everyday', 'Common words that instantly sharpen how you sound'),
  stretch('Stretch', 'Polished words for work, writing, and good conversation'),
  advanced('Advanced', 'Rarer, precise words for when you want to impress');

  const Difficulty(this.label, this.description);
  final String label;
  final String description;
}

/// A vocabulary word with everything the exercises need.
class Word {
  const Word({
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.insteadOf,
    required this.example,
    required this.cloze,
    required this.clozeAnswer,
    required this.forms,
    this.difficulty = Difficulty.stretch,
  });

  final String word;
  final String partOfSpeech;
  final String definition;

  /// Plainer words or phrases this word can replace in everyday speech.
  final List<String> insteadOf;
  final String example;

  /// A sentence with `___` where [clozeAnswer] belongs.
  final String cloze;
  final String clozeAnswer;

  /// Every accepted inflection, used to check typed answers and sentences.
  final List<String> forms;

  final Difficulty difficulty;

  String get id => word;
}
