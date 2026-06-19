import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/shared/widgets/primary_button.dart';

/// Settings page placeholder.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const _Section(
            title: '默认设置',
            child: Text('节拍器默认 BPM（80）、节拍器音量将在后续任务接入。'),
          ),
          const SizedBox(height: 16),
          const _Section(
            title: '关于',
            child: Text('版本号、开源许可、隐私说明、内容声明。'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: '关于',
            icon: Icons.info_outline,
            onPressed: () => context.push('/settings/about'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: '隐私说明',
            icon: Icons.privacy_tip_outlined,
            onPressed: () => context.push('/settings/privacy'),
          ),
          const SizedBox(height: 8),
          PrimaryButton(
            label: '内容声明',
            icon: Icons.article_outlined,
            onPressed: () => context.push('/settings/content'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
