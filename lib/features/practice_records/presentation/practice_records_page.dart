import 'package:flutter/material.dart';

/// Practice records list page placeholder.
class PracticeRecordsPage extends StatelessWidget {
  const PracticeRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('练习记录'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '练习记录（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('按日期倒序的练习记录列表将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
