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

  String get id => word;
}
