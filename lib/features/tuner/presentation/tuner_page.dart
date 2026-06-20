// Manual tuning guide page (T011).
//
// Scope:
// - Visual-only tuner guide. No audio capture, no microphone,
//   no pitch detection, no real-time analysis — see the task
//   brief §边界限制. The page is a structured checklist for
//   beginners to follow by ear (or with an external tuner).
// - The page reads [tunerControllerProvider] and forwards button
//   taps to the controller.
// - All "confirmed" state is held in memory only:
//     * It is never written to a database (no Drift).
//     * It is never written to SharedPreferences.
//     * It is lost whenever the application process is killed
//       (cold restart, OS reclaim, etc.).
//   Completion state does NOT feed back into T007's home page
//   "today's practice" task list.
// - The widget tree is split into small components
//   (TunerDisclaimer / TuningProgress / TuningStringCard) so
//   this file stays short and each piece is independently
//   testable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/tuner/application/tuner_controller.dart';
import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuner_disclaimer.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuning_progress.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuning_string_card.dart';

class TunerPage extends ConsumerWidget {
  const TunerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TunerState state = ref.watch(tunerControllerProvider);
    final TunerController controller =
        ref.read(tunerControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    final List<TuningString> displayOrder =
        state.stringsInDisplayOrder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('调音辅助'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const TunerDisclaimer(),
            const SizedBox(height: 16),
            _PresetSummary(theme: theme, state: state),
            const SizedBox(height: 16),
            TuningProgress(
              confirmedCount: state.confirmedCount,
              totalCount: state.totalCount,
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              theme: theme,
              text: '请按顺序调好以下四根弦（G → C → E → A）',
            ),
            const SizedBox(height: 8),
            for (final TuningString s in displayOrder) ...<Widget>[
              TuningStringCard(
                tuningString: s,
                isConfirmed: state.isConfirmed(s.stringNumber),
                onToggleConfirmed: () =>
                    controller.toggleConfirmed(s.stringNumber),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            _ActionRow(
              state: state,
              onReset: controller.resetAll,
              onConfirmAll: controller.confirmAll,
            ),
            const SizedBox(height: 24),
            if (state.allConfirmed) const _AllDoneBanner(),
          ],
        ),
      ),
    );
  }
}

/// "标准调弦：G - C - E - A" summary shown just below the
/// disclaimer so the user sees the target ordering without
/// scrolling through the cards.
class _PresetSummary extends StatelessWidget {
  const _PresetSummary({required this.theme, required this.state});

  final ThemeData theme;
  final TunerState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '标准调弦',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'G - C - E - A',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '本页面只做弦名指导，不做频率检测。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small section title used above the string cards.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Bottom action row: "全部重置" + optional "全部标记已调好".
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.state,
    required this.onReset,
    required this.onConfirmAll,
  });

  final TunerState state;
  final VoidCallback onReset;
  final VoidCallback onConfirmAll;

  @override
  Widget build(BuildContext context) {
    final bool canReset = state.confirmedCount > 0;
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey<String>('tuner-reset-all'),
            onPressed: canReset ? onReset : null,
            icon: const Icon(Icons.refresh),
            label: const Text('全部重置'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            key: const ValueKey<String>('tuner-confirm-all'),
            onPressed: state.allConfirmed ? null : onConfirmAll,
            icon: const Icon(Icons.done_all),
            label: const Text('全部标记已调好'),
          ),
        ),
      ],
    );
  }
}

/// Friendly banner shown once every string is confirmed.
class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.celebration_outlined,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '四根弦都已确认。建议再完整拨一次 G-C-E-A 复核音色。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}