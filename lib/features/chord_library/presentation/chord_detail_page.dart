import 'package:flutter/material.dart';

/// Chord detail page placeholder.
///
/// T006: receives [chordId] from the router but does not look up a real
/// diagram yet — that comes with the chord data module in a later task.
class ChordDetailPage extends StatelessWidget {
  const ChordDetailPage({super.key, required this.chordId});

  final String chordId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('和弦 $chordId'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '和弦详情（占位）',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('chordId: $chordId'),
            const SizedBox(height: 12),
            const Text('指法图与组成音说明将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
