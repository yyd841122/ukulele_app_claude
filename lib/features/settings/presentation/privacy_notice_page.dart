import 'package:flutter/material.dart';

/// Privacy notice page placeholder.
class PrivacyNoticePage extends StatelessWidget {
  const PrivacyNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私说明'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '隐私说明（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              'MVP 不收集任何用户行为数据；录音仅本地保存；不申请 INTERNET 权限。\n'
              '完整文案将在 T013 接入。',
            ),
          ],
        ),
      ),
    );
  }
}
