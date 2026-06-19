import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ukulele_app/app/app.dart';

Future<void> main() async {
  // T007: localise "yyyy年M月d日 EEEE" used on the home page header.
  // We initialise the locales we actually format with; add more here if
  // the app starts rendering dates in other locales.
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN');
  runApp(const ProviderScope(child: UkuleleApp()));
}
