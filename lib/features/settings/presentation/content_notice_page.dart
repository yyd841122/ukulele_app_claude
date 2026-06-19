import 'package:flutter/material.dart';

/// Content notice page placeholder.
class ContentNoticePage extends StatelessWidget {
  const ContentNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('内容声明'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '内容声明（占位）',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            Text(
              '本应用内置内容均为原创（CC0）或公版内容。\n'
              '我们尊重知识产权，不提供未经授权的商业歌曲内容。\n'
              '完整文案将在 T013 接入。',
            ),
          ],
        ),
      ),
    );
  }
}
