// Tests for the user-facing text on the settings / about / privacy /
// content pages.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - The pages must NOT carry any of the historical placeholder
//   copy ("占位", "T013 接入", "后续任务接入", "后续由 ..." etc.)
//   that the device-acceptance pass flagged.
// - The privacy notice must not claim to save real audio —
//   practice records are simulated takes (self-rating + mock
//   playback) and the page must say so.
// - The about page must NOT make any open-source-license claim
//   we cannot back up; the MVP ships no LICENSE file, and the
//   page must reflect that honestly.
//
// We render each page as the production code does, then walk the
// rendered text tree and assert the forbidden tokens are absent.
// We do not need to couple these tests to the controller / DB
// layer because none of the four pages is stateful — they are
// pure StatelessWidgets that pull colours from `Theme.of(context)`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/settings/presentation/about_page.dart';
import 'package:ukulele_app/features/settings/presentation/content_notice_page.dart';
import 'package:ukulele_app/features/settings/presentation/privacy_notice_page.dart';
import 'package:ukulele_app/features/settings/presentation/settings_page.dart';

/// Renders [page] inside a tall `MaterialApp` viewport so the
/// `ListView` contents that live below the fold on a phone-sized
/// surface are still laid out and reachable from
/// `find.text(...)`. (Each page is rendered tall on purpose so the
/// full body — including the bottom bullet lists — is rendered
/// into the widget tree.)
Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    MaterialApp(
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

/// Concatenates every visible Text / SelectableText data string in
/// the current widget tree. Used to scan the rendered pages for
/// forbidden tokens.
String _renderedText(WidgetTester tester) {
  final Finder allText = find.byType(Text);
  final StringBuffer buffer = StringBuffer();
  for (final Element el in allText.evaluate()) {
    final Text w = el.widget as Text;
    final String? data = w.data;
    if (data != null && data.isNotEmpty) {
      buffer.writeln(data);
    }
  }
  return buffer.toString();
}

/// Tokens that the device-acceptance pass flagged as user-visible
/// placeholder / task-id wording. None of these may appear on the
/// four pages anymore.
const List<String> _forbiddenTokens = <String>[
  '占位',
  'T007',
  'T013',
  '后续任务',
  '后续接入',
  '后续由',
  '临时实现',
  // Settings page old copy.
  '节拍器默认 BPM（80）',
  // About page old copy.
  '版本号、开源许可等',
];

/// Tokens that may appear ONLY inside a denial / negation
/// (e.g. "不保存真实录音文件"). The page must never use them as
/// a positive claim.
final Map<String, RegExp> _positiveClaimsForbidden = <String, RegExp>{
  // A real positive claim of open-source licensing — "本项目
  // 采用开源协议", "本应用基于开源代码", "已遵循开源许可", etc.
  // Plain "开源许可证" inside a denial ("未随附开源许可证") is
  // NOT matched.
  '开源 license': RegExp(
    r'(采用|基于|遵循|使用)\s*开源|开源\s*(协议|许可|许可证)\s*(下|发布)|'
    r'(发布|提供)\s*于\s*开源',
  ),
  // A positive claim that the app saves real recordings / audio.
  // We forbid the substring "保存真实录音" / "保存录音" only when
  // it is NOT preceded by "不" in the same sentence.
  '保存真实录音': RegExp(r'(?<!不)保存\s*(真实\s*)?录音'),
  // A blanket public-domain / CC0 claim (the previous wording
  // said "内置内容均为原创（CC0）或公版内容").
  'CC0 / 公版 blanket claim':
      RegExp(r'(均为|全部\s*(是|为))\s*(原创|公版|CC0)|原创\s*\(\s*CC0'),
};

/// Asserts every Text widget on the current page does NOT contain
/// any of [tokens].
void _expectNoForbiddenTokens(
  WidgetTester tester, {
  required List<String> tokens,
  required String pageLabel,
}) {
  final Finder allText = find.byType(Text);
  for (final Element el in allText.evaluate()) {
    final Text w = el.widget as Text;
    final String? data = w.data;
    if (data == null || data.isEmpty) {
      continue;
    }
    for (final String token in tokens) {
      expect(data, isNot(contains(token)),
          reason: '$pageLabel must not contain "$token"; got "$data"');
    }
  }
}

/// Asserts that none of the positive-claim patterns match any
/// visible Text. The patterns target specific over-promises
/// (e.g. "we ship an open-source license", "we save real
/// recordings", "everything is CC0") that the device-acceptance
/// pass flagged. Plain mentions of the words in a denial
/// context ("不保存真实录音文件", "未随附开源许可证") are NOT
/// matched by these patterns.
void _expectNoPositiveClaims(
  WidgetTester tester, {
  required Map<String, RegExp> patterns,
  required String pageLabel,
}) {
  final Finder allText = find.byType(Text);
  for (final Element el in allText.evaluate()) {
    final Text w = el.widget as Text;
    final String? data = w.data;
    if (data == null || data.isEmpty) {
      continue;
    }
    for (final MapEntry<String, RegExp> entry in patterns.entries) {
      expect(data, isNot(matches(entry.value)),
          reason: '$pageLabel must not positively claim '
              '"${entry.key}"; got "$data"');
    }
  }
}

void main() {
  group('Settings / About / Privacy / Content — user copy', () {
    testWidgets(
        'Settings page exposes the default-settings section '
        'and the about / privacy / content entry points',
        (WidgetTester tester) async {
      await _pumpPage(tester, const SettingsPage());
      // New default-settings copy.
      expect(find.text('默认设置'), findsOneWidget);
      expect(find.text('节拍器默认速度为 80 BPM。'), findsOneWidget);
      // The about section is still described and links are present.
      expect(find.text('关于'), findsWidgets);
      expect(find.text('隐私说明'), findsOneWidget);
      expect(find.text('内容声明'), findsOneWidget);
      // The historical "后续任务接入" / placeholder wording is gone.
      _expectNoForbiddenTokens(
        tester,
        tokens: _forbiddenTokens,
        pageLabel: 'Settings page',
      );
    });

    testWidgets(
        'About page describes the actual MVP capabilities '
        'and does not claim a license we do not ship',
        (WidgetTester tester) async {
      await _pumpPage(tester, const AboutPage());
      // The "what the MVP does" sections are present.
      expect(find.text('当前版本包含的能力'), findsOneWidget);
      expect(find.text('当前版本不包含'), findsOneWidget);
      expect(find.text('账号体系与云同步'), findsOneWidget);
      expect(find.text('真实麦克风录音与音频文件保存'), findsOneWidget);
      // License section is honest: explicit note that no LICENSE
      // file ships today. We assert the disclaimer is present
      // and the historical placeholder is gone.
      expect(find.textContaining('未随附开源许可证文件'), findsOneWidget,
          reason: 'About page must explicitly disclose that the '
              'current build ships no LICENSE file');
      _expectNoForbiddenTokens(
        tester,
        tokens: _forbiddenTokens,
        pageLabel: 'About page',
      );
      _expectNoPositiveClaims(
        tester,
        patterns: <String, RegExp>{
          '开源 license': _positiveClaimsForbidden['开源 license']!,
        },
        pageLabel: 'About page',
      );
    });

    testWidgets('Privacy notice does not claim to save real audio',
        (WidgetTester tester) async {
      await _pumpPage(tester, const PrivacyNoticePage());
      // The new headline replaces "（占位）".
      expect(find.text('隐私说明'), findsWidgets);
      expect(find.text('隐私说明（占位）'), findsNothing);
      // The privacy bullet list explicitly denies real audio
      // capture / RECORD_AUDIO permission.
      expect(
        find.textContaining('不采集麦克风音频'),
        findsOneWidget,
      );
      expect(
        find.textContaining('不申请麦克风'),
        findsOneWidget,
      );
      expect(
        find.textContaining('不保存真实录音文件'),
        findsOneWidget,
        reason: 'Privacy page must explicitly state the app does '
            'not save real audio files',
      );
      // The page must NOT describe the stored records as
      // "real recordings" (without a denial) — i.e. no positive
      // claim that the app captures or saves real audio.
      final String rendered = _renderedText(tester);
      // The page may mention "真实录音" only in the context of
      // an explicit denial ("不保存真实录音文件"). We walk the
      // rendered text and ensure every occurrence of the
      // substring appears next to a "不" in the same sentence.
      for (final String line in rendered.split('\n')) {
        final String trimmed = line.trim();
        if (trimmed.contains('真实录音') && !trimmed.startsWith('不')) {
          fail('Privacy page must not positively claim to save real '
              'audio; offending line: "$trimmed"');
        }
      }
      _expectNoForbiddenTokens(
        tester,
        tokens: _forbiddenTokens,
        pageLabel: 'Privacy page',
      );
      _expectNoPositiveClaims(
        tester,
        patterns: <String, RegExp>{
          '保存真实录音': _positiveClaimsForbidden['保存真实录音']!,
        },
        pageLabel: 'Privacy page',
      );
    });

    testWidgets(
        'Content notice removes the CC0 / public-domain '
        'blanket claim and the T013 placeholder line',
        (WidgetTester tester) async {
      await _pumpPage(tester, const ContentNoticePage());
      expect(find.text('内容声明'), findsWidgets);
      expect(find.text('内容声明（占位）'), findsNothing);
      // New careful wording mentions what the app does NOT include
      // (commercial recordings / lyrics / tabs) and the honest
      // licensing note.
      expect(
        find.textContaining('不提供未经授权'),
        findsOneWidget,
      );
      expect(
        find.textContaining('不会做无法证明的版权或许可证承诺'),
        findsOneWidget,
      );
      _expectNoForbiddenTokens(
        tester,
        tokens: _forbiddenTokens,
        pageLabel: 'Content page',
      );
      _expectNoPositiveClaims(
        tester,
        patterns: <String, RegExp>{
          'CC0 / 公版 blanket claim':
              _positiveClaimsForbidden['CC0 / 公版 blanket claim']!,
        },
        pageLabel: 'Content page',
      );
    });
  });
}
