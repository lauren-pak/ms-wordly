import 'package:flutter/material.dart';

import '../services/progress_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final ProgressStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final controller = TextEditingController(text: widget.store.apiKey);
  bool obscure = true;

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
          Text('Sentence checking', style: text.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Add your own Claude API key and Claude will check whether each '
            'sentence you write uses the word correctly, and suggest a better '
            'version. Without a key, you check your sentences yourself.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Get a key at console.anthropic.com (API keys). Each check costs '
            'well under a cent. The key is stored only on this device.',
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
              FilledButton(onPressed: save, child: const Text('Save')),
            ],
          ),
        ],
      ),
    );
  }
}
