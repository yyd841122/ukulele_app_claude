// About page.
//
// Shows the current factual capabilities of the app, the version
// label shipped with the build, and a short note about what the
// MVP does NOT do (account, cloud sync, real recording). The
// previous placeholder text promised "version, open-source
// license" content that this task cannot deliver, and the copy
// has been replaced with what is actually true today.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - No `后续任务接入` wording.
// - No false claim of an open-source license (we do not ship a
//   LICENSE file today).
// - The list of capabilities matches the shipped app surface:
//   offline practice tool, no account, no cloud sync, no real
//   recording.

import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('关于'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const Text(
            'Ukulele App',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '离线尤克里里练习工具',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text('当前版本', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const Text('MVP 内部版本 0.1.0（仅用于本地练习）'),
          const SizedBox(height: 20),
          Text('当前版本包含的能力', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const _BulletList(
            items: <String>[
              '首页：今日练习（按弦、拨弦、调音、节拍器、和弦库等基础练习）',
              '调音器、节拍器、单音练习、和弦库、模拟录音回放',
              '今日练习记录（完成状态、模拟录音条目）只保存在本机',
              '核心功能完全离线运行，不申请麦克风权限',
            ],
          ),
          const SizedBox(height: 20),
          Text('当前版本不包含', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          const _BulletList(
            items: <String>[
              '账号体系与云同步',
              '真实麦克风录音与音频文件保存',
              '商业歌曲歌词或商业曲谱内容',
            ],
          ),
          const SizedBox(height: 20),
          Text('许可与来源', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            '本应用当前版本未随附开源许可证文件；'
            '如需了解代码来源或引用素材，请直接联系项目维护者。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('• '),
                Expanded(
                  child: Text(item, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
