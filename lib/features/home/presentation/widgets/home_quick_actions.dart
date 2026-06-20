// Quick action tiles at the bottom of the home page.
//
// T007 scope: mirrors the T006 navigation tiles (tuner / single-note /
// chords / metronome / records / settings) so the user can reach any
// destination without having to scroll past the day's task list. This is
// NOT a "today" feature, just the existing nav hub in a tidier layout.
//
// T012: added the "录音回放" entry so the basic recording playback
// flow is reachable from the home page in addition to today's task
// cards. Order matches the day-plan order: tuning -> notes -> chords
// -> metronome -> recording -> records -> settings.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/shared/widgets/primary_button.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '快捷入口',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        PrimaryButton(
          label: '调音器',
          icon: Icons.tune,
          onPressed: () => context.push('/tuner'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '单音练习',
          icon: Icons.music_note,
          onPressed: () => context.push('/single-note'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '和弦库',
          icon: Icons.library_music,
          onPressed: () => context.push('/chords'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '节拍器',
          icon: Icons.timer,
          onPressed: () => context.push('/metronome'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '录音回放',
          icon: Icons.mic,
          onPressed: () => context.push('/recording'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '练习记录',
          icon: Icons.history,
          onPressed: () => context.push('/records'),
        ),
        const SizedBox(height: 8),
        PrimaryButton(
          label: '设置',
          icon: Icons.settings,
          onPressed: () => context.push('/settings'),
        ),
      ],
    );
  }
}
