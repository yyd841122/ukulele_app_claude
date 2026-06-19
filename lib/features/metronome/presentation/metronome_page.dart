import 'package:flutter/material.dart';

/// Metronome page placeholder.
class MetronomePage extends StatelessWidget {
  const MetronomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('节拍器'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '节拍器（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('4/4 拍、BPM 50-200（默认 80）、开始 / 暂停 / 停止将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
