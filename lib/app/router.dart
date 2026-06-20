import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/chord_library/presentation/chord_detail_page.dart';
import 'package:ukulele_app/features/chord_library/presentation/chord_library_page.dart';
import 'package:ukulele_app/features/home/presentation/home_page.dart';
import 'package:ukulele_app/features/metronome/presentation/metronome_page.dart';
import 'package:ukulele_app/features/practice_records/presentation/practice_record_detail_page.dart';
import 'package:ukulele_app/features/practice_records/presentation/practice_records_page.dart';
import 'package:ukulele_app/features/recording/presentation/recording_page.dart';
import 'package:ukulele_app/features/settings/presentation/about_page.dart';
import 'package:ukulele_app/features/settings/presentation/content_notice_page.dart';
import 'package:ukulele_app/features/settings/presentation/privacy_notice_page.dart';
import 'package:ukulele_app/features/settings/presentation/settings_page.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/single_note_practice_page.dart';
import 'package:ukulele_app/features/tuner/presentation/tuner_page.dart';

/// Top-level [GoRouter] instance used by `MaterialApp.router`.
///
/// T006: a flat list of routes, no [ShellRoute], no redirects, no deep
/// linking. Unknown paths render the [NotFoundPage] placeholder.
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  errorBuilder: (BuildContext context, GoRouterState state) =>
      const NotFoundPage(),
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) =>
          const HomePage(),
    ),
    GoRoute(
      path: '/tuner',
      name: 'tuner',
      builder: (BuildContext context, GoRouterState state) =>
          const TunerPage(),
    ),
    GoRoute(
      path: '/single-note',
      name: 'single-note',
      builder: (BuildContext context, GoRouterState state) =>
          const SingleNotePracticePage(),
    ),
    GoRoute(
      path: '/chords',
      name: 'chords',
      builder: (BuildContext context, GoRouterState state) =>
          const ChordLibraryPage(),
      routes: <RouteBase>[
        GoRoute(
          path: ':chordId',
          name: 'chord-detail',
          builder: (BuildContext context, GoRouterState state) =>
              ChordDetailPage(
            chordId: state.pathParameters['chordId'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/metronome',
      name: 'metronome',
      builder: (BuildContext context, GoRouterState state) =>
          const MetronomePage(),
    ),
    GoRoute(
      path: '/recording',
      name: 'recording',
      builder: (BuildContext context, GoRouterState state) =>
          const RecordingPage(),
    ),
    GoRoute(
      path: '/records',
      name: 'records',
      builder: (BuildContext context, GoRouterState state) =>
          const PracticeRecordsPage(),
      routes: <RouteBase>[
        GoRoute(
          path: ':recordId',
          name: 'record-detail',
          builder: (BuildContext context, GoRouterState state) =>
              PracticeRecordDetailPage(
            recordId: state.pathParameters['recordId'] ?? '',
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (BuildContext context, GoRouterState state) =>
          const SettingsPage(),
      routes: <RouteBase>[
        GoRoute(
          path: 'about',
          name: 'settings-about',
          builder: (BuildContext context, GoRouterState state) =>
              const AboutPage(),
        ),
        GoRoute(
          path: 'privacy',
          name: 'settings-privacy',
          builder: (BuildContext context, GoRouterState state) =>
              const PrivacyNoticePage(),
        ),
        GoRoute(
          path: 'content',
          name: 'settings-content',
          builder: (BuildContext context, GoRouterState state) =>
              const ContentNoticePage(),
        ),
      ],
    ),
  ],
);

/// Simple placeholder shown for unknown routes (404).
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('页面未找到'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text(
                '抱歉，找不到该页面。',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
