// Single-note practice page.
//
// T009 scope:
// - Top-level page for the MVP single-note practice feature.
//   Renders the active note, its position diagram, info card,
//   progress indicator, and prev/next + mark-as-practiced
//   controls.
// - State is read from [singleNotePracticeControllerProvider]; the
//   page itself is a [ConsumerWidget] so it can both watch state
//   and invoke the controller's methods.
// - All "practiced" state is held in memory only:
//     * It is never written to a database (no Drift).
//     * It is never written to SharedPreferences.
//     * It is lost whenever the application process is killed
//       (cold restart, OS reclaim, etc.).
//   Whether the state survives *navigating away from this page
//   and back* depends on the provider's lifecycle, which this
//   page does not control. A future task can promote the
//   practiced set to a shared service or `autoDispose` the
//   provider if a different lifecycle is required.
// - No audio, no microphone, no recording, no network — see the
//   task brief §边界限制.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/single_note_practice/application/single_note_practice_controller.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/widgets/single_note_info_card.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/widgets/single_note_position_diagram.dart';

class SingleNotePracticePage extends ConsumerWidget {
  const SingleNotePracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SingleNotePracticeState state =
        ref.watch(singleNotePracticeControllerProvider);
    final SingleNotePracticeController controller =
        ref.read(singleNotePracticeControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    final SingleNote? current = state.currentNote;

    return Scaffold(
      appBar: AppBar(
        title: const Text('单音练习'),
      ),
      body: SafeArea(
        child: current == null
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _IntroBlurb(theme: theme),
                  const SizedBox(height: 16),
                  _CurrentNoteHeader(note: current),
                  const SizedBox(height: 12),
                  Center(
                    child: SingleNotePositionDiagram(note: current),
                  ),
                  const SizedBox(height: 16),
                  SingleNoteInfoCard(note: current),
                  const SizedBox(height: 16),
                  _Progress(state: state),
                  const SizedBox(height: 12),
                  _Controls(
                    state: state,
                    onPrevious: controller.previousNote,
                    onNext: controller.nextNote,
                    onTogglePracticed: controller.toggleCurrentPracticed,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Intro blurb that sets the beginner-friendly expectation
/// (no audio, no scoring — just press and pluck).
class _IntroBlurb extends StatelessWidget {
  const _IntroBlurb({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '入门单音练习：先看清所在弦和品位，按好之后用拇指拨响即可。本练习不录音、不评分，专注于按弦和拨弦手感。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "当前：C 音" header.
class _CurrentNoteHeader extends StatelessWidget {
  const _CurrentNoteHeader({required this.note});

  final SingleNote note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          '当前：',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(width: 4),
        Text(
          note.displayName,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// "已练习 2 / 6" progress label.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final SingleNotePracticeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Text(
        '已练习 ${state.practicedCount} / ${state.totalCount}',
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Row of three actions: prev, toggle-practiced, next.
///
/// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
/// - The previous single-row `Row` with `Expanded` buttons wrapped
///   vertically ("上/一/个") at 320px width with
///   `textScaler = 1.4` because each Chinese label was forced into
///   ~1/4 of the screen width and Flutter broke it character by
///   character. To keep the labels horizontally readable on every
///   supported screen, the controls are now stacked into two rows:
///     * Top row: prev / next (icon + short label, 1:1).
///     * Bottom row: the primary "toggle practiced" action as a
///       full-width button.
///   This layout is intentionally simple — it stays readable at
///   320px × 1.4 text scale and on tablets alike, and it never
///   has to choose between shrinking the label or letting it
///   wrap mid-word.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onPrevious,
    required this.onNext,
    required this.onTogglePracticed,
  });

  final SingleNotePracticeState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTogglePracticed;

  @override
  Widget build(BuildContext context) {
    final bool isPracticed = state.isCurrentPracticed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
                label: const Text('上一个', maxLines: 1, softWrap: false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                label: const Text('下一个', maxLines: 1, softWrap: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onTogglePracticed,
          icon: Icon(isPracticed ? Icons.check_circle : Icons.check),
          label: Text(
            isPracticed ? '取消已练习' : '标记已练习',
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }
}

/// Fallback shown only if the built-in note list ever becomes
/// empty (defensive — the MVP ships 7 notes).
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.music_off, size: 48),
            SizedBox(height: 12),
            Text('没有可练习的单音。'),
          ],
        ),
      ),
    );
  }
}
