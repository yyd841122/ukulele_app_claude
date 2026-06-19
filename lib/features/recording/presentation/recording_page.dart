import 'package:flutter/material.dart';

/// Recording page placeholder.
class RecordingPage extends StatelessWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('录音'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '录音（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('麦克风录音（最长 5 分钟）、4:30 提示、文件本地保存将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
