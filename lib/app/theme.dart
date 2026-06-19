import 'package:flutter/material.dart';

/// Builds the MVP [ThemeData].
///
/// T006: keep it intentionally simple — Material 3 with a warm wood-tone
/// seed color. No dark theme, no custom fonts.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFB9793D),
    ),
  );
}
