import 'package:flutter/material.dart';

/// Practice record detail page placeholder.
///
/// T006: receives [recordId] from the router. No database lookup yet.
class PracticeRecordDetailPage extends StatelessWidget {
  const PracticeRecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('记录 $recordId'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '练习记录详情（占位）',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('recordId: $recordId'),
            const SizedBox(height: 12),
            const Text('回放控件与录音文件丢失处理将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
