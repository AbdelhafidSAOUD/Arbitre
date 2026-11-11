import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../logic/dates.dart';
import '../theme.dart';

/// Radar d'auto-évaluation (valeurs de 1 à 5).
class RadarChart extends StatelessWidget {
  const RadarChart({super.key, required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) => Semantics(
        label: [for (var i = 0; i < labels.length; i++) '${labels[i]} ${frNumber(values[i])} sur 5'].join(', '),
        child: AspectRatio(aspectRatio: 340 / 260, child: CustomPaint(painter: _RadarPainter(labels, values, context.sc))),
      );
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.labels, this.values, this.c);
  final List<String> labels;
  final List<double> values;
  final SiffletColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = min(size.width * .26, size.height * .34);
    Offset pt(int i, double r) {
      final a = -pi / 2 + i * 2 * pi / n;
      return center + Offset(cos(a), sin(a)) * r;
    }

    final grid = Paint()
      ..color = c.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var k = 1; k <= 5; k++) {
      final path = Path()..addPolygon([for (var i = 0; i < n; i++) pt(i, radius * k / 5)], true);
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, pt(i, radius), grid);
    }
    final poly = [for (var i = 0; i < n; i++) pt(i, radius * values[i].clamp(0, 5) / 5)];
    canvas.drawPath(Path()..addPolygon(poly, true), Paint()..color = c.card.withValues(alpha: .35));
    canvas.drawPath(
        Path()..addPolygon(poly, true),
        Paint()
          ..color = c.card
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (final p in poly) {
      canvas.drawCircle(p, 3.5, Paint()..color = c.card);
    }
    for (var i = 0; i < n; i++) {
      final p = pt(i, radius + 14);
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(text: '${labels[i]}\n', style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: kBody)),
          TextSpan(text: '${frNumber(values[i])}/5', style: TextStyle(color: c.ink, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: kBody)),
        ]),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * .34);
      var dx = p.dx - tp.width / 2;
      if (p.dx > center.dx + 5) dx = p.dx - 4;
      if (p.dx < center.dx - 5) dx = p.dx - tp.width + 4;
      dx = dx.clamp(0, size.width - tp.width);
      final dy = (p.dy - tp.height / 2).clamp(0, size.height - tp.height).toDouble();
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values || old.c != c;
}

/// Courbe des notes d'observation (sur 20).
class NotesSparkline extends StatelessWidget {
  const NotesSparkline({super.key, required this.points});
  final List<(String, double)> points; // (date, note), du plus ancien au plus récent

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Évolution des notes d’observation, dernière note ${frNumber(points.last.$2)} sur 20',
        child: AspectRatio(aspectRatio: 320 / 110, child: CustomPaint(painter: _SparkPainter(points, context.sc))),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.c);
  final List<(String, double)> points;
  final SiffletColors c;

  @override
  void paint(Canvas canvas, Size size) {
    const pl = 28.0, pr = 12.0, pt = 12.0, pb = 22.0;
    final lo = min(10.0, points.map((p) => p.$2).reduce(min));
    final hi = max(18.0, points.map((p) => p.$2).reduce(max));
    double x(int i) => points.length == 1 ? pl : pl + i * (size.width - pl - pr) / (points.length - 1);
    double y(double v) => pt + (hi - v) * (size.height - pt - pb) / (hi - lo);
    final text = TextStyle(color: c.muted, fontSize: 10, fontFamily: kBody);

    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(Offset(pl, y(v)), Offset(size.width - pr, y(v)), Paint()..color = c.line);
      final tp = TextPainter(text: TextSpan(text: frNumber(v), style: text), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pl - 5 - tp.width, y(v) - tp.height / 2));
    }
    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(i), y(points[i].$2));
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    final area = Path.from(line)
      ..lineTo(x(points.length - 1), size.height - pb)
      ..lineTo(x(0), size.height - pb)
      ..close();
    canvas.drawPath(area, Paint()..color = c.pitch.withValues(alpha: .12));
    canvas.drawPath(
        line,
        Paint()
          ..color = c.pitch
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i].$2)), i == points.length - 1 ? 4.5 : 2.5, Paint()..color = c.pitch);
    }
    final first = TextPainter(text: TextSpan(text: shortDate(points.first.$1), style: text), textDirection: TextDirection.ltr)..layout();
    first.paint(canvas, Offset(x(0), size.height - 14));
    final last = TextPainter(text: TextSpan(text: shortDate(points.last.$1), style: text), textDirection: TextDirection.ltr)..layout();
    last.paint(canvas, Offset(x(points.length - 1) - last.width, size.height - 14));
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.points != points || old.c != c;
}
