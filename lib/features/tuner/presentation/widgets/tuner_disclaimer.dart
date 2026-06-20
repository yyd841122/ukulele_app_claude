// Reusable disclaimer / notice widget for the tuner guide page.
//
// T011 scope:
// - Pure presentation: takes a title + body and renders the
//   info banner used at the top of the tuner page.
// - We expose this as a small private widget rather than a
//   public API — it has only one caller today and keeping the
//   surface tiny keeps the file easy to refactor later.

import 'package:flutter/material.dart';

/// Info banner explaining that the MVP ships a manual tuning
/// guide, not a real tuner.
class TunerDisclaimer extends StatelessWidget {
  const TunerDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '手动调音指导',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前版本是手动调音指导页面，不会调用麦克风，不会识别声音，也不会检测频率。'
                  '请按下方说明手动调整琴弦，并用耳朵或外部调音 App 确认音高。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}