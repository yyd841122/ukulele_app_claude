// Static visual widget for the `C ↔ Am` 4/4 down-strum pattern.
//
// T043 scope:
// - Pure Flutter widgets + CustomPaint. No third-party drawing
//   library, no image / SVG assets.
// - The widget is intentionally **static**: it does not animate,
//   does not listen to a metronome, does not capture audio, and is
//   not clickable. Per PRD §6.5 "节奏型 不做", the metronome
//   domain stays unaware of rhythm patterns — this diagram is the
//   visual overlay referenced from the lesson / chord detail /
//   metronome pages (wiring lives in T044+).
// - Layout: 4 equally-spaced beat cells. Each cell renders, top
//   to bottom:
//     1. Chord name (`C` or `Am`)
//     2. Beat number (`1` / `2` / `3` / `4`)
//     3. Down-strum arrow (filled triangle drawn in CustomPaint)
//   A horizontal "timeline" line runs underneath the cells; a
//   small `*` marker sits between cell 2 and cell 3 to call out
//   the chord switch on beat 3.
// - The time signature `4/4` is drawn in the top-left.
// - Sizing is responsive: callers control the on-screen size via
//   [width]. The height is derived as `width * 0.55` (shorter than
//   the chord diagram because there is no fret stack). A
//   `FittedBox(scaleDown)` wrapper guarantees no overflow when the
//   caller asks for an awkward width.
// - Text accessibility: every visible label is a real Flutter
//   `Text` widget (not a `TextPainter` inside the canvas), so
//   `find.text(...)` works in widget tests and screen readers get
//   each label as a discrete semantics node. The whole widget is
//   also wrapped in a `Semantics(container: true, label: ...)`
//   block so a screen reader announces it once as a coherent
//   group rather than reading every label in isolation.
//
// Why this widget is opinionated (not a generic painter):
// - Matches the project's `ChordDiagram` / `SingleNotePositionDiagram`
//   pattern — every shipped diagram is its own widget, not a
//   configurable one. T043 only needs the C↔Am lesson; if a
//   second lesson ever lands, the painter can be factored then.

import 'package:flutter/material.dart';

/// Reusable static visual for the `C ↔ Am` 4/4 down-strum lesson.
///
/// Default width is 280 logical pixels. Pass a smaller `width`
/// (e.g. `200`) for compact placements — the internal
/// `FittedBox(scaleDown)` ensures the diagram never overflows.
class CAmDownStrumPatternDiagram extends StatelessWidget {
  const CAmDownStrumPatternDiagram({
    super.key,
    this.width = 280,
    this.showLabels = true,
  }) : assert(width > 0, 'width must be > 0');

  /// Target width in logical pixels. Height is derived as
  /// `width * 0.55`.
  final double width;

  /// When `false`, hides the `4/4` time signature and the per-cell
  /// chord / beat labels. Useful for very compact list previews
  /// (still keeps the down-strum arrows so the rhythm remains
  /// legible).
  final bool showLabels;

  /// Hard-coded rhythm payload. Pulled from
  /// `docs/learning/lesson_c_am_down_4x4.md` §4.4 + §7.1:
  /// 4 beats per measure, down-strum, C on beats 1-2 and Am on
  /// beats 3-4 (chord switches on beat 3).
  static const List<String> _kChordSequence = <String>['C', 'C', 'Am', 'Am'];
  static const int _kBeatsPerMeasure = 4;
  static const String _kTimeSignature = '4/4';

  /// Semantics label. Kept to a single sentence so screen readers
  /// announce the diagram once as a group instead of reading each
  /// beat in isolation.
  static const String _kSemanticsLabel =
      '4/4 拍，每拍下扫一次；前两拍弹 C 和弦，后两拍弹 Am 和弦';

  @override
  Widget build(BuildContext context) {
    final double height = width * 0.55;
    final ThemeData theme = Theme.of(context);
    final Color arrowColor = theme.colorScheme.primary;
    final Color textColor = theme.colorScheme.onSurface;
    final Color labelColor = theme.colorScheme.onSurfaceVariant;
    final Color lineColor = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Semantics(
      container: true,
      label: _kSemanticsLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: <Widget>[
                // 1) CustomPaint draws the timeline, the chord-switch
                //    marker line and the 4 down-strum arrows. The
                //    arrow geometry depends on the cell layout, so
                //    the painter needs the same `width` / `height`
                //    / `showLabels` inputs the Text widgets use.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CAmDownStrumPatternPainter(
                      beatsPerMeasure: _kBeatsPerMeasure,
                      arrowColor: arrowColor,
                      lineColor: lineColor,
                      showLabels: showLabels,
                    ),
                  ),
                ),
                // 2) The chord-switch `*` marker is a real Text widget
                //    (between cells 2 and 3) so it shows up in
                //    `find.text('*')` for tests AND screen readers.
                if (showLabels)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: width * 0.5,
                        bottom: height * 0.10,
                      ),
                      child: Text(
                        '*',
                        style: TextStyle(
                          color: arrowColor,
                          fontWeight: FontWeight.w700,
                          fontSize: width * 0.10,
                        ),
                      ),
                    ),
                  ),
                // 3) The 4 beat cells: each cell renders its chord
                //    name, beat number and reserves vertical space
                //    for the arrow drawn by the painter above.
                if (showLabels)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (int beatIndex = 0;
                          beatIndex < _kBeatsPerMeasure;
                          beatIndex++)
                        Expanded(
                          child: _BeatCell(
                            chord: _kChordSequence[beatIndex],
                            beatNumber: beatIndex + 1,
                            isDownbeat: beatIndex == 0,
                            textColor: textColor,
                            accentColor: arrowColor,
                          ),
                        ),
                    ],
                  ),
                // 4) The time signature in the top-left, drawn LAST
                //    so it sits on top of the painter's first beat
                //    cell. We use IgnorePointer / excludeFromSemantics
                //    on the time signature Text because the outer
                //    Semantics label already names "4/4".
                if (showLabels)
                  Positioned(
                    left: width * 0.10,
                    top: 0,
                    child: ExcludeSemantics(
                      child: Text(
                        _kTimeSignature,
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w500,
                          fontSize: width * 0.10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-beat cell: chord name (top) + beat number (middle).
/// The down-strum arrow is drawn by the parent painter in the
/// bottom strip so the text widget stays free of canvas code.
class _BeatCell extends StatelessWidget {
  const _BeatCell({
    required this.chord,
    required this.beatNumber,
    required this.isDownbeat,
    required this.textColor,
    required this.accentColor,
  });

  final String chord;
  final int beatNumber;
  final bool isDownbeat;
  final Color textColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle chordStyle = TextStyle(
      color: textColor,
      fontSize: 18,
      fontWeight: isDownbeat ? FontWeight.w700 : FontWeight.w500,
    );
    final TextStyle beatStyle = TextStyle(
      color: isDownbeat ? accentColor : textColor,
      fontSize: 22,
      fontWeight: isDownbeat ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Text(chord, style: chordStyle),
          const SizedBox(height: 4),
          Text('$beatNumber', style: beatStyle),
        ],
      ),
    );
  }
}

class _CAmDownStrumPatternPainter extends CustomPainter {
  _CAmDownStrumPatternPainter({
    required this.beatsPerMeasure,
    required this.arrowColor,
    required this.lineColor,
    required this.showLabels,
  });

  final int beatsPerMeasure;
  final Color arrowColor;
  final Color lineColor;
  final bool showLabels;

  // Geometry constants. All values are in the painter's local
  // coordinate space (0..size.width, 0..size.height) and are
  // derived at paint time from the canvas size. Mirrors the
  // chord-diagram conventions so the two diagrams feel visually
  // consistent side by side.
  static const double _topMarginFraction = 0.18;
  static const double _sideMarginFraction = 0.10;
  static const double _timelineStrokeWidth = 1.4;
  static const double _arrowStrokeWidth = 1.6;
  static const double _arrowHeadFraction = 0.40;
  static const double _textStripFraction = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    // Margin rectangle. The top strip reserves room for the time
    // signature and the chord labels; the bottom strip reserves
    // room for the timeline + the chord-switch marker.
    final double top = size.height * _topMarginFraction;
    final double bottom = size.height - top;
    final double left = size.width * _sideMarginFraction;
    final double right = size.width - left;

    // The text cells occupy the top `_textStripFraction` of the
    // available area; arrows occupy the rest.
    final double textStripBottom = top + (bottom - top) * _textStripFraction;
    final double arrowTopY = textStripBottom + size.height * 0.04;
    final double arrowBottomY = bottom - size.height * 0.10;

    // 4 evenly spaced beat cells across [left, right].
    final double cellWidth = (right - left) / beatsPerMeasure;

    for (int beatIndex = 0; beatIndex < beatsPerMeasure; beatIndex++) {
      final double xCenter = left + (beatIndex + 0.5) * cellWidth;
      _paintDownArrow(
        canvas,
        Offset(xCenter, (arrowTopY + arrowBottomY) / 2),
        cellWidth * _arrowHeadFraction,
        arrowBottomY - arrowTopY,
        arrowColor,
      );
    }

    // Timeline (horizontal axis beneath the cells).
    final Paint timelinePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _timelineStrokeWidth;
    final double timelineY = bottom + size.height * 0.05;
    canvas.drawLine(
      Offset(left, timelineY),
      Offset(right, timelineY),
      timelinePaint,
    );
  }

  /// Draw a down-strum arrow as a filled triangle (head) with a
  /// short stem line. Sizing is driven by [headHalfWidth] and
  /// [totalHeight] so the painter scales with the surrounding
  /// cell width without leaking IconTheme dependencies.
  void _paintDownArrow(
    Canvas canvas,
    Offset center,
    double headHalfWidth,
    double totalHeight,
    Color color,
  ) {
    final double stemTopY = center.dy - totalHeight / 2;
    final double stemBottomY = center.dy + totalHeight / 2;
    final double headTopY = stemBottomY - headHalfWidth;
    final double headBottomY = stemBottomY + headHalfWidth * 0.6;

    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _arrowStrokeWidth
      ..strokeCap = StrokeCap.round;
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Stem.
    canvas.drawLine(
      Offset(center.dx, stemTopY),
      Offset(center.dx, headTopY),
      strokePaint,
    );

    // Triangular head, pointing down.
    final Path head = Path()
      ..moveTo(center.dx - headHalfWidth, headTopY)
      ..lineTo(center.dx + headHalfWidth, headTopY)
      ..lineTo(center.dx, headBottomY)
      ..close();
    canvas.drawPath(head, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _CAmDownStrumPatternPainter old) {
    return old.beatsPerMeasure != beatsPerMeasure ||
        old.arrowColor != arrowColor ||
        old.lineColor != lineColor ||
        old.showLabels != showLabels;
  }
}