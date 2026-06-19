import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/shared/widgets/primary_button.dart';

/// Home page placeholder.
///
/// T006: a simple navigation hub. No 7-day plan logic, no real "today"
/// data, no business state — just enough to smoke-test the router.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ukulele App'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const _TodayPracticeBanner(),
            const SizedBox(height: 16),
            _NavTile(
              icon: Icons.tune,
              label: '调音器',
              path: '/tuner',
            ),
            _NavTile(
              icon: Icons.music_note,
              label: '单音练习',
              path: '/single-note',
            ),
            _NavTile(
              icon: Icons.library_music,
              label: '和弦库',
              path: '/chords',
            ),
            _NavTile(
              icon: Icons.timer,
              label: '节拍器',
              path: '/metronome',
            ),
            _NavTile(
              icon: Icons.mic,
              label: '录音',
              path: '/recording',
            ),
            _NavTile(
              icon: Icons.history,
              label: '练习记录',
              path: '/records',
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              label: '设置',
              icon: Icons.settings,
              onPressed: () => context.push('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPracticeBanner extends StatelessWidget {
  const _TodayPracticeBanner();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '今日练习',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'T006 占位：7 天循环计划将在 T007 接入。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(path),
      ),
    );
  }
}
