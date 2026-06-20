// Shared application clock (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Provides a single `DateTime Function()` Provider for the entire
// app. Production code reads it via `ref.read(appClockProvider)()`
// instead of calling `DateTime.now()` directly so tests can pin
// "now" without monkey-patching globals.
//
// Migration note (T013.4A0):
// - This provider used to live inside
//   `lib/features/home/application/today_practice_controller.dart`
//   under the name `clockProvider`. It was a feature-local
//   dependency even though the recording save flow will also need
//   it (every `completedAt` stamp, every persisted `practiceDate`
//   resolution, every `dayIndex` lookup). Moving it to the shared
//   layer makes the cross-feature ownership explicit and prevents
//   a second copy from being created later under a different name.
// - The previous alias `clockProvider` is intentionally NOT
//   preserved as a forwarding export. Every call site now imports
//   `appClockProvider` from this file.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application-wide clock provider.
///
/// Returns a `DateTime Function()` that defaults to
/// [DateTime.now]. Tests override this provider with a pinned
/// clock so every `DateTime.now()` substitute is deterministic.
final Provider<DateTime Function()> appClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);
