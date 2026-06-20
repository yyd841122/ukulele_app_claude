// Renders a 4-string ukulele position diagram for a single note.
//
// T009 scope:
// - Pure Flutter widgets + CustomPaint. No third-party drawing
//   library, no image assets.
// - String numbering inside the data model matches the chord
//   library (T008):
//     stringNumber 1 = A
//     stringNumber 2 = E
//     stringNumber 3 = C
//     stringNumber 4 = G
//   The diagram itself is rendered in the conventional beginner
//   "chart" orientation: G, C, E, A from left to right, so the
//   visible left-to-right string order is [4, 3, 2, 1]. The
//   [visibleSingleNoteStringOrder] helper centralises this mapping
//   so the painter, the tests, and any future widget cannot drift
//   apart — and so the orientation rule is shared across features.
// - The diagram highlights exactly one string / fret cell (the
//   active note) using the primary color. Other strings / frets
//   are rendered as a neutral grid.
// - Open strings (fret 0) are drawn as an "O" above the top nut
//   line on the active column, and the column is highlighted with
//   a soft bar so beginners can immediately tell "no fret needed".
// - Pressed strings (fret 1..N) are drawn as a filled dot at the
//   pressed fret; when a finger index is known we render the
//   number inside the dot.
// - Sizing is responsive: callers control the width via [width];
//   the height is derived from the aspect ratio. The default fits
//   a phone screen comfortably.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';

/// Left-to-right string order used by the single-note diagram, in
/// terms of the internal [SingleNote.stringNumber] values.
///
/// For the MVP, the ukulele has exactly 4 strings and the diagram
/// always shows them in the beginner "chart" orientation: G, C, E,
/// A from left to right. Because the data model numbers strings
/// 1..4 as A, E, C, G, the visible order is the reverse:
/// `[4, 3, 2, 1]`. This mirrors [visibleStringOrder] from the
/// chord diagram and is exposed as a top-level helper so unit
/// tests can pin the mapping without spinning up a widget tree.
///
/// NOTE: We deliberately do *not* re-export
/// `chord_library/.../chord_diagram.dart`'s `visibleStringOrder`
/// here — the chord library and the single-note feature are
/// independent domains, and a future change in one must not
/// silently propagate to the other.
List<int> visibleSingleNoteStringOrder() => <int>[4, 3, 2, 1];

/// Reusable ukulele position diagram for a single note.
///
/// Renders [note] as a 4-string, 4-fret diagram with the active
/// note highlighted. Use [width] to control the on-screen size;
/// height is derived from the aspect ratio.
class SingleNotePositionDiagram extends StatelessWidget {
  const SingleNotePositionDiagram({
    super.key,
    required this.note,
    this.width = 220,
    this.showLabels = true,
  }) : assert(width > 0, 'width must be > 0');

  /// The note to render. Must pass [SingleNote.validate].
  final SingleNote note;

  /// Target width in logical pixels. Height is derived as
  /// `width * 1.1` to leave room for the open-string label above
  /// the nut and the finger-number text inside the dot.
  final double width;

  /// When `true` (default) render the "O" label above the nut and
  /// the finger number inside the dot. Setting this to `false`
  /// produces a clean silhouette useful for compact previews.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final double height = width * 1.1;
    final ThemeData theme = Theme.of(context);
    final Color lineColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final Color dotColor = theme.colorScheme.primary;
    final Color textColor = theme.colorScheme.onPrimary;
    final Color labelColor = theme.colorScheme.onSurfaceVariant;
    final Color highlightColor =
        theme.colorScheme.primary.withValues(alpha: 0.12);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SingleNotePositionDiagramPainter(
          note: note,
          lineColor: lineColor,
          dotColor: dotColor,
          textColor: textColor,
          labelColor: labelColor,
          highlightColor: highlightColor,
          showLabels: showLabels,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _SingleNotePositionDiagramPainter extends CustomPainter {
  _SingleNotePositionDiagramPainter({
    required this.note,
    required this.lineColor,
    required this.dotColor,
    required this.textColor,
    required this.labelColor,
    required this.highlightColor,
    required this.showLabels,
    required this.textDirection,
  });

  final SingleNote note;
  final Color lineColor;
  final Color dotColor;
  final Color textColor;
  final Color labelColor;
  final Color highlightColor;
  final bool showLabels;
  final TextDirection textDirection;

  // Geometry constants. All values are in the painter's local
  // coordinate space (0..size.width, 0..size.height) and are
  // derived at paint time from the canvas size. Mirrors the
  // chord-diagram layout so the two diagrams feel visually
  // consistent side by side.
  static const double _topMarginFraction = 0.18;
  static const double _sideMarginFraction = 0.12;
  static const double _fretStrokeWidth = 1.4;
  static const double _stringStrokeWidth = 1.2;
  static const double _dotRadiusFraction = 0.075;
  static const double _labelFontSizeFraction = 0.085;

  // Always 4 frets for the MVP — the brief asks for "at least 4
  // frets" and 4 matches the chord diagram's default window, which
  // is enough to display every shipped note (the highest is fret 2).
  static const int _fretCount = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final List<int> stringOrder = visibleSingleNoteStringOrder();
    final int stringCount = stringOrder.length;

    // Reserve the top strip for the open-string label and the
    // bottom strip symmetrically. The playable area is the
    // rectangle in between.
    final double top = size.height * _topMarginFraction;
    final double bottom = size.height - top;
    final double left = size.width * _sideMarginFraction;
    final double right = size.width - left;

    final double stringSpacing = (right - left) / (stringCount - 1);
    final double fretSpacing = (bottom - top) / _fretCount;

    // Resolve the column index of the active string. This is the
    // single source of truth used by the highlight / label / dot
    // painters below.
    final int activeColumn = _activeColumn(stringOrder);

    // Soft column highlight (drawn under the grid so the lines
    // stay crisp on top of it). Only rendered for pressed notes
    // because an open string already gets a strong "O" marker.
    if (activeColumn >= 0 && !note.isOpen) {
      final double xCenter = left + activeColumn * stringSpacing;
      final double colHalf = stringSpacing * 0.45;
      final Rect highlightRect = Rect.fromLTRB(
        xCenter - colHalf,
        top,
        xCenter + colHalf,
        bottom,
      );
      final Paint highlightPaint = Paint()..color = highlightColor;
      canvas.drawRect(highlightRect, highlightPaint);
    }

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _fretStrokeWidth;

    // Nut (the heavy top line) — matches the chord diagram so the
    // two visuals are interchangeable at a glance.
    final Paint nutPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _fretStrokeWidth * 2.0;

    // Horizontal fret lines.
    for (int fretIndex = 0; fretIndex <= _fretCount; fretIndex++) {
      final double y = top + fretIndex * fretSpacing;
      final Paint p = fretIndex == 0 ? nutPaint : linePaint;
      canvas.drawLine(Offset(left, y), Offset(right, y), p);
    }

    // Vertical string lines.
    final Paint stringPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stringStrokeWidth;
    for (int s = 0; s < stringCount; s++) {
      final double x = left + s * stringSpacing;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), stringPaint);
    }

    if (!showLabels) {
      // Still need to draw the dot for the pressed case, so we
      // fall through to the dot painter below.
    } else {
      // Open-string label above the nut, on the active column.
      if (note.isOpen && activeColumn >= 0) {
        final double labelY =
            top - (size.height * _topMarginFraction) * 0.55;
        final double labelFontSize = size.width * _labelFontSizeFraction;
        final double xCenter = left + activeColumn * stringSpacing;
        _paintCenteredText(
          canvas,
          '○',
          Offset(xCenter, labelY),
          labelFontSize,
          labelColor,
        );
      }
    }

    // Pressed-fret dot. Only rendered when the note is fretted.
    if (note.isFretted) {
      final double dotRadius =
          (size.shortestSide * _dotRadiusFraction).clamp(4.0, 18.0);
      final double fingerFontSize = dotRadius * 1.1;
      final int relativeFret = note.fret; // startFret == 1
      if (relativeFret >= 1 && relativeFret <= _fretCount &&
          activeColumn >= 0) {
        final double xCenter = left + activeColumn * stringSpacing;
        final double y = top + (relativeFret - 0.5) * fretSpacing;

        final Paint dotPaint = Paint()
          ..color = dotColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(xCenter, y), dotRadius, dotPaint);

        if (note.finger != null) {
          _paintCenteredText(
            canvas,
            note.finger.toString(),
            Offset(xCenter, y),
            fingerFontSize,
            textColor,
            bold: true,
          );
        }
      }
    }
  }

  /// Returns the 0-based column index of the active string in
  /// [stringOrder], or `-1` if the note's string is not in the
  /// order (defensive — well-formed data never triggers this).
  int _activeColumn(List<int> stringOrder) {
    return stringOrder.indexOf(note.stringNumber);
  }

  void _paintCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: textDirection,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SingleNotePositionDiagramPainter old) {
    return old.note != note ||
        old.lineColor != lineColor ||
        old.dotColor != dotColor ||
        old.textColor != textColor ||
        old.labelColor != labelColor ||
        old.highlightColor != highlightColor ||
        old.showLabels != showLabels;
  }
}
