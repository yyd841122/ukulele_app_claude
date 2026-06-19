import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Chord library page placeholder.
///
/// T006: shows a hard-coded list of stub chord names so the
/// `ChordDetailPage` route can be smoke-tested through `context.push`.
class ChordLibraryPage extends StatelessWidget {
  const ChordLibraryPage({super.key});

  static const List<MapEntry<String, String>> _stubChords =
      <MapEntry<String, String>>[
    MapEntry<String, String>('c', 'C'),
    MapEntry<String, String>('am', 'Am'),
    MapEntry<String, String>('f', 'F'),
    MapEntry<String, String>('g', 'G'),
    MapEntry<String, String>('g7', 'G7'),
    MapEntry<String, String>('dm', 'Dm'),
    MapEntry<String, String>('em', 'Em'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('和弦库'),
      ),
      body: ListView.separated(
        itemCount: _stubChords.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final MapEntry<String, String> entry = _stubChords[index];
          return ListTile(
            title: Text(entry.value),
            subtitle: Text('id = ${entry.key}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/chords/${entry.key}'),
          );
        },
      ),
    );
  }
}
