// Privacy notice page.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - Replaces the previous `隐私说明（占位）` heading and the
//   `完整文案将在 T013 接入` placeholder paragraph with
//   copy that accurately describes what the shipped app does
//   today. No claim of real audio storage; the practice records
//   stored on device are simulated takes (self-rating + mock
//   playback), not microphone captures.

import 'package:flutter/material.dart';

class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私说明'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            '隐私说明',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '本应用对您的数据做以下承诺：',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          const _BulletList(
            items: <String>[
              '不收集或上传任何个人信息、账号或使用行为数据。',
              '今日练习完成状态、练习记录和"模拟录音"条目只保存在您本机；'
                  '卸载应用或清除数据后会被一并删除，不会同步到任何服务器。',
              '不采集麦克风音频，也不保存真实录音文件。',
              '不申请麦克风（RECORD_AUDIO）权限。',
              '核心功能完全离线运行，App 不发起任何网络请求来读取或上传数据。',
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '本说明适用于当前发布的内部版本；后续若引入新的数据收集方式，'
            '会先在此页面更新说明再随版本发布。',
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
