// Renders a 4-string ukulele chord diagram from a [ChordFingering].
//
// T008 scope:
// - Pure Flutter widgets + CustomPaint for the dots. No third-party
//   drawing library, no image assets.
// - String numbering inside the data model:
//     * stringNumber 1 = A   (the lowest-pitched string on a
//                              high-G re-entrant ukulele)
//     * stringNumber 2 = E
//     * stringNumber 3 = C
//     * stringNumber 4 = G
//   This matches the [built_in_chords.dart] data layout, where each
//   voicing is stored string 1..4 (A, E, C, G) so the frets line up
//   in the order they are physically strung on the instrument.
// - The diagram itself is rendered in the conventional beginner
//   "chart" orientation: when the player holds the ukulele in
//   playing position the *top* string (closest to the player's face)
//   is G. We render G as the leftmost column, then C, E, A from
//   left to right. That means the *visible* left-to-right string
//   order is [4, 3, 2, 1] — opposite of the internal [stringNumber]
//   order. The [visibleStringOrder] helper centralises this mapping
//   so the painter, the tests, and any future widget (e.g. a tab
//   editor) cannot drift apart.
// - Open strings (fret 0) are drawn as an "O" above the top nut line.
// - Muted strings (fret null) are drawn as an "X" above the top nut.
// - Pressed strings (fret 1..N) are drawn as filled dots; when a
//   finger index is known we render the number inside the dot.
// - Sizing is responsive: callers control the width via [width]; the
//   height is derived from the aspect ratio. The default fits a phone
//   screen comfortably.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/chord_library/domain/chord_fingering.dart';

/// Left-to-right string order used by the diagram, in terms of the
/// internal [ChordStringPosition.stringNumber] values.
///
/// For the MVP, the ukulele has exactly 4 strings and the diagram
/// always shows them in the beginner "chart" orientation: G, C, E, A
/// from left to right. Because the data model numbers strings 1..4
/// as A, E, C, G, the visible order is the reverse: `[4, 3, 2, 1]`.
///
/// Exposed as a top-level helper so unit tests can pin the mapping
/// without spinning up a widget tree, and so a future widget (e.g. a
/// tab editor, or a left-handed variant) can call into the same
/// source of truth rather than re-deriving the order.
List<int> visibleStringOrder() => <int>[4, 3, 2, 1];

/// Reusable ukulele chord diagram widget.
///
/// Renders [fingering] as a 4-string, [fingering.maxFretShown]-fret
/// diagram. Use [width] to control the on-screen size; height is
/// derived from the aspect ratio.
class ChordDiagram extends StatelessWidget {
  const ChordDiagram({
    super.key,
    required this.fingering,
    this.width = 220,
    this.showLabels = true,
  })  : assert(width > 0, 'width must be > 0');

  /// The fingering to render. Must pass [ChordFingering.validate].
  final ChordFingering fingering;

  /// Target width in logical pixels. Height is derived as
  /// `width * 1.1` to leave room for the open / muted labels above
  /// the nut and the finger-number text inside dots.
  final double width;

  /// When `true` (default) render the "O" / "X" labels above the nut
  /// and the finger numbers inside the pressed-fret dots. Setting
  /// this to `false` produces a clean silhouette useful for compact
  /// list previews.
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final double height = width * 1.1;
    final ThemeData theme = Theme.of(context);
    final Color lineColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final Color dotColor = theme.colorScheme.primary;
    final Color textColor = theme.colorScheme.onPrimary;
    final Color labelColor = theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _ChordDiagramPainter(
          fingering: fingering,
          lineColor: lineColor,
          dotColor: dotColor,
          textColor: textColor,
          labelColor: labelColor,
          showLabels: showLabels,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

class _ChordDiagramPainter extends CustomPainter {
  _ChordDiagramPainter({
    required this.fingering,
    required this.lineColor,
    required this.dotColor,
    required this.textColor,
    required this.labelColor,
    required this.showLabels,
    required this.textDirection,
  });

  final ChordFingering fingering;
  final Color lineColor;
  final Color dotColor;
  final Color textColor;
  final Color labelColor;
  final bool showLabels;
  final TextDirection textDirection;

  // Geometry constants. All values are in the painter's local
  // coordinate space (0..size.width, 0..size.height) and are derived
  // at paint time from the canvas size.
  static const double _topMarginFraction = 0.18;
  static const double _sideMarginFraction = 0.12;
  static const double _fretStrokeWidth = 1.4;
  static const double _stringStrokeWidth = 1.2;
  static const double _dotRadiusFraction = 0.075;
  static const double _labelFontSizeFraction = 0.085;

  @override
  void paint(Canvas canvas, Size size) {
    // The ukulele always has 4 strings. We read the visible
    // left-to-right order from [visibleStringOrder] so the
    // orientation rule ("G, C, E, A from left to right") has a
    // single source of truth.
    final List<int> stringOrder = visibleStringOrder();
    final int stringCount = stringOrder.length;
    final int fretCount = fingering.maxFretShown;

    // Reserve the top strip for open / muted labels and the bottom
    // strip symmetrically. The playable area is the rectangle in
    // between.
    final double top = size.height * _topMarginFraction;
    final double bottom = size.height - top;
    final double left = size.width * _sideMarginFraction;
    final double right = size.width - left;

    final double stringSpacing = (right - left) / (stringCount - 1);
    final double fretSpacing = (bottom - top) / fretCount;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _fretStrokeWidth;

    // Nut (the heavy top line). We draw it slightly thicker when the
    // chord starts at fret 1, otherwise it is a regular fret line.
    final bool isAtNut = fingering.startFret == 1;
    final Paint nutPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAtNut ? _fretStrokeWidth * 2.0 : _fretStrokeWidth;

    // Horizontal fret lines.
    for (int fretIndex = 0; fretIndex <= fretCount; fretIndex++) {
      final double y = top + fretIndex * fretSpacing;
      final Paint p = fretIndex == 0 && isAtNut ? nutPaint : linePaint;
      canvas.drawLine(Offset(left, y), Offset(right, y), p);
    }

    // Vertical string lines. Index `s` walks the *visible* left-to-
    // right order, so column 0 is always the leftmost string the
    // player sees (G for the MVP).
    final Paint stringPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stringStrokeWidth;
    for (int s = 0; s < stringCount; s++) {
      final double x = left + s * stringSpacing;
      canvas.drawLine(Offset(x, top), Offset(x, bottom), stringPaint);
    }

    if (!showLabels) {
      return;
    }

    // Open / muted labels above the nut.
    final double labelY = top - (size.height * _topMarginFraction) * 0.55;
    final double labelFontSize = size.width * _labelFontSizeFraction;

    for (int s = 0; s < stringCount; s++) {
      final int stringNumber = stringOrder[s];
      final ChordStringPosition? pos = fingering.positionFor(stringNumber);
      if (pos == null) {
        continue;
      }
      final double x = left + s * stringSpacing;
      if (pos.isMuted) {
        _paintCenteredText(
          canvas,
          '×',
          Offset(x, labelY),
          labelFontSize,
          labelColor,
        );
      } else if (pos.isOpen) {
        _paintCenteredText(
          canvas,
          '○',
          Offset(x, labelY),
          labelFontSize,
          labelColor,
        );
      }
    }

    // Pressed-fret dots.
    final double dotRadius =
        (size.shortestSide * _dotRadiusFraction).clamp(4.0, 18.0);
    final double fingerFontSize = dotRadius * 1.1;

    for (int s = 0; s < stringCount; s++) {
      final int stringNumber = stringOrder[s];
      final ChordStringPosition? pos = fingering.positionFor(stringNumber);
      if (pos == null || pos.fret == null || pos.fret == 0) {
        continue;
      }
      final int relativeFret = pos.fret! - fingering.startFret + 1;
      if (relativeFret < 1 || relativeFret > fretCount) {
        // Out-of-range press; skip rather than draw a misleading dot.
        continue;
      }
      final double x = left + s * stringSpacing;
      final double y = top + (relativeFret - 0.5) * fretSpacing;

      final Paint dotPaint = Paint()
        ..color = dotColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), dotRadius, dotPaint);

      if (pos.finger != null) {
        _paintCenteredText(
          canvas,
          pos.finger.toString(),
          Offset(x, y),
          fingerFontSize,
          textColor,
          bold: true,
        );
      }
    }
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
  bool shouldRepaint(covariant _ChordDiagramPainter old) {
    return old.fingering != fingering ||
        old.lineColor != lineColor ||
        old.dotColor != dotColor ||
        old.textColor != textColor ||
        old.labelColor != labelColor ||
        old.showLabels != showLabels;
  }
}
