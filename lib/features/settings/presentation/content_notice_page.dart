// Content notice page.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - Replaces the previous `内容声明（占位）` heading and the
//   "CC0 / 公版" blanket claim with careful wording that
//   matches what the app actually ships:
//     * No commercial song recordings, lyrics or tabs.
//     * No claim we cannot back up (CC0 / blanket public-domain
//       claims are not made without per-asset verification).

import 'package:flutter/material.dart';

class ContentNoticePage extends StatelessWidget {
  const ContentNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容声明'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            '内容声明',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '关于本应用内置内容的事实陈述：',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const _BulletList(
            items: <String>[
              '当前版本内置的练习文案、和弦图与示意图不包含任何商业歌曲的录音、'
                  '歌词或曲谱内容。',
              '不提供未经授权的完整歌词或商业曲谱。',
              '不和未授权的第三方曲库、歌词源建立下载或同步关系。',
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '关于版权与许可证：',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const _BulletList(
            items: <String>[
              '本应用不针对未单独核实的素材做"全部 CC0"或"全部公版"的统一承诺。',
              '如果在练习文案、和弦说明或示意图中引用了第三方资料，'
                  '该处会单独注明来源和许可；不会做无法证明的版权或许可证承诺。',
              '如您发现疑似未授权内容，请联系项目维护者以便核查和修正。',
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '本说明适用于当前发布的内部版本；后续若新增任何第三方素材或'
            '授权信息，会先在此页面更新说明再随版本发布。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
            padding: const EdgeInsets.only(bottom: 6),
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
