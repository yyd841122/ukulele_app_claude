// Chord detail page.
//
// T008 scope:
// - Receives a [chordId] from the router and looks it up via
//   [chordByIdProvider]. When the id is unknown (or empty) the page
//   renders a friendly "not found" placeholder instead of crashing.
// - When the chord is found, shows the diagram, description, tips and
//   a small "related chords" jump list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/widgets/lesson_intro_card.dart';

class ChordDetailPage extends ConsumerWidget {
  const ChordDetailPage({super.key, required this.chordId});

  final String chordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Chord? chord = ref.watch(chordByIdProvider(chordId));
    final ThemeData theme = Theme.of(context);

    if (chord == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('和弦详情'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  '未找到 “$chordId” 和弦',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '请返回和弦库选择其他和弦。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go('/chords'),
                  child: const Text('返回和弦库'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(chord.displayName),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Center(
              child: ChordDiagram(fingering: chord.primaryVoicing, width: 240),
            ),
            const SizedBox(height: 16),
            Text(
              chord.displayName,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '难度：${chord.difficulty.label}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            // T044: the first beginner lesson (T041 / T042) only
            // layers onto Day 4 `day4_chord_switch`, whose
            // `routePath` is `/chords/c` (see
            // `practice_plan_constants.dart`). Other chord detail
            // pages (Am / F / G) do NOT show this card — T041 §7
            // R-01: a single entry point avoids the "two ways to
            // do the same thing" confusion.
            if (chord.id == 'c') ...<Widget>[
              const SizedBox(height: 16),
              const LessonIntroCard(),
            ],
            const SizedBox(height: 16),
            Text(
              '和弦说明',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              chord.description,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              '练习提示',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            for (final String tip in chord.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('• '),
                    Expanded(
                      child: Text(
                        tip,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            if (chord.relatedChordIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 20),
              Text(
                '相关和弦',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final String id in chord.relatedChordIds)
                    _RelatedChordChip(
                      id: id,
                      onTap: () => context.push('/chords/$id'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RelatedChordChip extends ConsumerWidget {
  const _RelatedChordChip({required this.id, required this.onTap});

  final String id;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Chord? related = ref.watch(chordByIdProvider(id));
    final String label = related?.name ?? id.toUpperCase();
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}
