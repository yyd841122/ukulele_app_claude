// Tests for [mapSelfRatingToSelfAssessment]
// (T013.4A0_RECORDING_SAVE_FOUNDATION).
//
// Contract under test:
// - `SelfRating.good` -> `SelfAssessment.good`
// - `SelfRating.okay` -> `SelfAssessment.neutral`
// - `SelfRating.retry` -> `SelfAssessment.needsImprovement`
// - `null` -> `null` (a user who skipped the rating is NOT
//   coerced into a default bucket).

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/recording/application/self_rating_mapper.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';

void main() {
  group('mapSelfRatingToSelfAssessment', () {
    test('good -> good', () {
      expect(
        mapSelfRatingToSelfAssessment(SelfRating.good),
        SelfAssessment.good,
      );
    });

    test('okay -> neutral', () {
      expect(
        mapSelfRatingToSelfAssessment(SelfRating.okay),
        SelfAssessment.neutral,
      );
    });

    test('retry -> needsImprovement', () {
      expect(
        mapSelfRatingToSelfAssessment(SelfRating.retry),
        SelfAssessment.needsImprovement,
      );
    });

    test('null -> null', () {
      expect(mapSelfRatingToSelfAssessment(null), isNull);
    });
  });
}
