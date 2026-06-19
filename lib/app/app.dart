import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/app/router.dart';
import 'package:ukulele_app/app/theme.dart';

/// Root widget of the ukulele MVP application.
///
/// T006: wires the app shell, theme and router. No business logic is added
/// here on purpose; feature pages are still placeholders.
class UkuleleApp extends ConsumerWidget {
  const UkuleleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Ukulele App',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
