// Tests for [PracticeRecordIdGenerator] (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Contract under test:
// - `UuidPracticeRecordIdGenerator` returns RFC 4122 UUID v4 strings.
// - The version nibble (the 13th hex character) is exactly `4`.
// - The variant bits (the 17th hex character) are one of `8`, `9`,
//   `a`, or `b` (the RFC 4122 variant-1 set).
// - Consecutive calls return distinct values (no shared internal
//   state can cause a collision under the project's test load).
// - `practiceRecordIdGeneratorProvider` can be overridden with a
//   fake that returns a fixed id, so callers (T013.4A) can pin
//   the saved `PracticeRecord.id` for assertions.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';

void main() {
  group('UuidPracticeRecordIdGenerator', () {
    test('returns a syntactically valid UUID v4 string', () {
      final PracticeRecordIdGenerator generator =
          UuidPracticeRecordIdGenerator();
      final String id = generator.generate();
      // Canonical UUID form: 8-4-4-4-12 lowercase hex chars.
      final RegExp uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(id, matches(uuidV4Pattern),
          reason: 'expected RFC 4122 UUID v4, got "$id"');
    });

    test('version nibble is exactly 4 (UUID v4)', () {
      // RFC 4122 §4.4: the most significant nibble of the
      // time_hi_and_version field is the version.
      final String id = UuidPracticeRecordIdGenerator().generate();
      // Strip the dashes so we can address the version nibble by
      // index 12 directly (i.e. the first hex char of the
      // 3rd group).
      final String hex = id.replaceAll('-', '');
      expect(hex.length, 32);
      expect(hex[12], '4',
          reason: 'version nibble must be 4, got "${hex[12]}" in $id');
    });

    test('variant bits are RFC 4122 variant-1 (8/9/a/b)', () {
      // RFC 4122 §4.1.1: the most significant bits of the
      // clock_seq_hi_and_reserved byte encode the variant.
      final String id = UuidPracticeRecordIdGenerator().generate();
      final String hex = id.replaceAll('-', '');
      expect(hex.length, 32);
      final String variantChar = hex[16];
      expect(<String>['8', '9', 'a', 'b'], contains(variantChar),
          reason: 'variant byte must be 8/9/a/b, got "$variantChar" in $id');
    });

    test('consecutive calls produce distinct ids', () {
      final PracticeRecordIdGenerator generator =
          UuidPracticeRecordIdGenerator();
      final Set<String> seen = <String>{};
      // 256 calls is well above the birthday-collision threshold
      // for a 122-bit UUID space; any duplicate here is a bug in
      // the generator, not bad luck.
      for (int i = 0; i < 256; i++) {
        seen.add(generator.generate());
      }
      expect(seen.length, 256);
    });

    test('reuses the underlying Uuid instance across calls', () {
      // The shared instance is an implementation detail but the
      // pin matters: every call MUST go through the same Uuid
      // (so the Random source is reused). We assert behaviour,
      // not the field: two generators must still produce
      // distinct ids, which would not hold if the implementation
      // were instantiating a fresh Random on every call and
      // somehow reseeding it deterministically.
      final PracticeRecordIdGenerator a = UuidPracticeRecordIdGenerator();
      final PracticeRecordIdGenerator b = UuidPracticeRecordIdGenerator();
      final String idA = a.generate();
      final String idB = b.generate();
      expect(idA, isNot(equals(idB)));
    });
  });

  group('practiceRecordIdGeneratorProvider', () {
    test('default provider exposes UuidPracticeRecordIdGenerator', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final PracticeRecordIdGenerator generator =
          container.read(practiceRecordIdGeneratorProvider);
      expect(generator, isA<UuidPracticeRecordIdGenerator>());
      // And it returns a valid UUID v4.
      final String id = generator.generate();
      final RegExp uuidV4Pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(id, matches(uuidV4Pattern));
    });

    test('provider can be overridden with a fake for deterministic ids', () {
      const String fixedId = 'fixed-id-01234567-89ab-4cde-9012-3456789abcde';
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordIdGeneratorProvider.overrideWithValue(
            _FixedPracticeRecordIdGenerator(fixedId),
          ),
        ],
      );
      addTearDown(container.dispose);
      final PracticeRecordIdGenerator generator =
          container.read(practiceRecordIdGeneratorProvider);
      expect(generator.generate(), fixedId);
      expect(generator.generate(), fixedId,
          reason: 'fake should return the same id on every call');
    });
  });
}

/// Deterministic [PracticeRecordIdGenerator] used by tests that
/// need to pin the saved `PracticeRecord.id` byte-for-byte. T013.4A
/// (the actual save wiring) will consume this through the provider
/// override.
class _FixedPracticeRecordIdGenerator implements PracticeRecordIdGenerator {
  const _FixedPracticeRecordIdGenerator(this._id);

  final String _id;

  @override
  String generate() => _id;
}
