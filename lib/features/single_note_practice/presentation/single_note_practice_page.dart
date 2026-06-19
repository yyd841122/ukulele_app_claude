import 'package:flutter/material.dart';

/// Single note practice page placeholder.
class SingleNotePracticePage extends StatelessWidget {
  const SingleNotePracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('单音练习'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '单音练习（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text('C / D / E / F / G / A / B 基础音名按弦练习将在后续任务接入。'),
          ],
        ),
      ),
    );
  }
}
