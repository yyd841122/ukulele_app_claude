import 'package:flutter/material.dart';

void main() {
  runApp(const UkuleleAppShell());
}

/// T004 project shell placeholder.
///
/// This widget intentionally contains no business logic, no routing,
/// no Riverpod, no database access, no tuner, no recording.
/// The real App Shell will be implemented in T006.
class UkuleleAppShell extends StatelessWidget {
  const UkuleleAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ukulele App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const _ShellPlaceholder(),
    );
  }
}

class _ShellPlaceholder extends StatelessWidget {
  const _ShellPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ukulele App Shell'),
      ),
      body: const Center(
        child: Text('Ukulele App Shell'),
      ),
    );
  }
}