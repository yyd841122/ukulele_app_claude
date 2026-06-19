// Icon hint for a single practice task.
//
// T007 scope:
// - We deliberately do NOT use Flutter's [IconData] (which is not const
//   safe in the way we need) and we do NOT use freezed / json_serializable
//   here because T007 must not pull in code generation for trivial models.
// - The UI layer maps [PracticeTaskIcon] -> [IconData] at render time.

enum PracticeTaskIcon {
  tuner,
  singleNote,
  chord,
  metronome,
  recording,
  selfAssessment,
}
