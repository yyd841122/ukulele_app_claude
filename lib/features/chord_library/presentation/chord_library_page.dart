// Chord library list page.
//
// T008 scope:
// - Reads the built-in chord list from [chordLibraryProvider].
// - Renders one [ChordCard] per chord in the order defined by the
//   data module. Tapping a card navigates to `/chords/:id`.
// - Adds a short introductory blurb aimed at absolute beginners.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_card.dart';

class ChordLibraryPage extends ConsumerWidget {
  const ChordLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Chord> chords = ref.watch(chordLibraryProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('和弦库'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              '从 4 个基础和弦开始',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '以下和弦是尤克里里最常用的入门和弦，建议按顺序逐个练习。点击卡片查看指法图与练习提示。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final Chord chord in chords)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChordCard(
                  chord: chord,
                  onTap: () => context.push('/chords/${chord.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
