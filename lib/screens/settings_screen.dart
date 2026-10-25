import 'package:flutter/material.dart';

import '../data/word_bank.dart';
import '../services/progress_store.dart';
import '../services/sentence_challenges.dart';
import '../services/sentence_grader.dart';
import '../widgets/difficulty_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final controller = TextEditingController(text: widget.store.apiKey);
  bool obscure = true;
  bool testing = false;

  /// Saves the key and grades a sample sentence to prove it works.
  Future<void> test() async {
    await widget.store.setApiKey(controller.text);
    final key = widget.store.apiKey;
    if (key == null) return;
    setState(() => testing = true);
    String message;
    try {
      final r = await ClaudeSentenceGrader(key).grade(
        wordsById['candid']!,
        challengesFor(wordsById['candid']!).first,
        'Can I be candid about why the plan worries me?',
      );
      message = 'It works! Claude says: ${r.feedback}';
    } on GradeException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    setState(() => testing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    await widget.store.setApiKey(controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.store.apiKey == null
              ? 'Key removed. Sentences use self-check.'
              : 'Saved. Claude will check your sentences.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Word difficulty', style: text.titleLarge),
          const SizedBox(height: 4),
          DifficultyOptions(store: widget.store),
          const Divider(height: 32),
          Text('Sentence checking', style: text.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Add your own Claude API key and Claude will check whether each '
            'sentence you write uses the word correctly, and suggest a better '
            'version. Without a key, you check your sentences yourself.',
          ),
          const SizedBox(height: 8),
          const Text(
            'To get a key: sign in at console.anthropic.com, add a few '
            'dollars of credit under Billing, then go to API keys and create '
            'one. Each check costs well under a cent. The key is stored only '
            'on this device.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            obscureText: obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Claude API key',
              hintText: 'sk-ant-…',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  controller.clear();
                  save();
                },
                child: const Text('Remove'),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: testing ? null : test,
                child: Text(testing ? 'Testing…' : 'Test key'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
