import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/progress_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ProgressStore.open();
  runApp(MsWordlyApp(store: store));
}

class MsWordlyApp extends StatelessWidget {
  const MsWordlyApp({super.key, required this.store});

  final ProgressStore store;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5B3CC4),
        brightness: b,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Ms Wordly',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: HomeScreen(store: store),
    );
  }
}
