import 'package:flutter/material.dart';

/// Tuner page placeholder.
///
/// T006: scaffolding only. No audio capture, no pitch detection, no GCEA
/// string switching UI.
class TunerPage extends StatelessWidget {
  const TunerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('调音器'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '调音器（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'G / C / E / A 四弦手动调音、频率与偏差提示将在后续任务接入。',
            ),
          ],
        ),
      ),
    );
  }
}
