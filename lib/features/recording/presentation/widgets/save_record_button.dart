// Save button for the simulated recording take (T013.4A).
//
// Scope:
// - A single FilledButton.tonalIcon that drives the save flow.
// - Reads its enablement from the immutable
//   [RecordingPracticeState] so the rules live with the
//   controller (single source of truth) — see
//   [RecordingPracticeState.canSave] / [isSaved] / [isSaving].
// - Does NOT touch the Repository, the database, the Resolver,
//   or the Clock. All of that lives in the Controller.
//
// Visual states:
// - `initial / disabled`  -> muted label "保存到练习记录".
// - `canSave`             -> enabled, same label.
// - `isSaving`            -> disabled, "正在保存…", inline
//                            progress indicator.
// - `isSaved`             -> disabled, "已保存", check icon.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';

/// Save button that commits the current take as a
/// [PracticeRecord] via [RecordingPracticeController.saveCurrentTake].
class SaveRecordButton extends StatelessWidget {
  const SaveRecordButton({
    super.key,
    required this.state,
    required this.onPressed,
  });

  final RecordingPracticeState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget label;
    final Widget icon;
    final bool enabled;
    if (state.isSaving) {
      label = const Text('正在保存…');
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
      enabled = false;
    } else if (state.isSaved) {
      label = const Text('已保存');
      icon = const Icon(Icons.check_circle_outline);
      enabled = false;
    } else {
      label = const Text('保存到练习记录');
      icon = const Icon(Icons.save_outlined);
      enabled = state.canSave;
    }

    return FilledButton.tonalIcon(
      key: const ValueKey<String>('recording-save'),
      onPressed: enabled ? onPressed : null,
      icon: icon,
      label: label,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        textStyle: theme.textTheme.titleSmall,
      ),
    );
  }
}
