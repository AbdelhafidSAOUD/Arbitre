import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../logic/offside.dart';
import '../theme.dart';

/// Demi-terrain du simulateur de hors-jeu, à l'échelle (1 unité = 1 m).
class OffsidePitch extends StatelessWidget {
  const OffsidePitch({super.key, required this.scenario, required this.reveal});
  final OffsideScenario scenario;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Demi-terrain. Attaquants en bleu, défenseurs en rouge, gardien en jaune. '
              'L’attaque se dirige vers le haut. L’attaquant à juger est entouré.',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _PitchPainter.viewW / _PitchPainter.viewH,
              child: CustomPaint(painter: _PitchPainter(scenario, reveal, c)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            _legend(c.attacker, 'Attaquants', c),
            _legend(c.red, 'Défenseurs', c),
            _legend(c.card, 'Gardien', c),
            Text('Attaque vers le haut', style: TextStyle(fontSize: 12, color: c.muted)),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, SiffletColors c) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: c.muted)),
        ],
      );
}

class _PitchPainter extends CustomPainter {
  _PitchPainter(this.s, this.reveal, this.c);
  final OffsideScenario s;
  final bool reveal;
  final SiffletColors c;

  static const minX = -3.0, minY = -4.0, viewW = 74.0, viewH = 64.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / viewW;
    canvas.save();
    canvas.scale(k);
    canvas.translate(-minX, -minY);

    // Pelouse rayée
    canvas.drawRect(const Rect.fromLTWH(minX, minY, viewW, viewH), Paint()..color = c.grass);
    for (var i = 0; i < 9; i++) {
      if (i.isOdd) {
        canvas.drawRect(Rect.fromLTWH(minX, i * 7.5 - 3, viewW, 7.5), Paint()..color = c.grass2);
      }
    }

    final chalk = Paint()
      ..color = Colors.white.withValues(alpha: .85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .3;
    canvas.drawRect(const Rect.fromLTWH(0, 0, 68, 70), chalk);
    canvas.drawRect(const Rect.fromLTWH(13.84, 0, 40.32, 16.5), chalk);
    canvas.drawRect(const Rect.fromLTWH(24.84, 0, 18.32, 5.5), chalk);
    canvas.drawRect(const Rect.fromLTWH(30.34, -2, 7.32, 2), chalk);
    // Arc de la surface : partie du cercle de 9,15 m autour du point de penalty hors surface.
    final a = acos(5.5 / 9.15);
    canvas.drawArc(Rect.fromCircle(center: const Offset(34, 11), radius: 9.15), pi / 2 - a, 2 * a, false, chalk);
    canvas.drawLine(const Offset(0, halfwayY), const Offset(68, halfwayY), chalk);
    canvas.save();
    canvas.clipRect(const Rect.fromLTWH(0, 0, 68, 57));
    canvas.drawCircle(const Offset(34, halfwayY), 9.15, chalk);
    canvas.restore();
    final spot = Paint()..color = Colors.white.withValues(alpha: .85);
    canvas.drawCircle(const Offset(34, 11), .3, spot);
    canvas.drawCircle(const Offset(34, halfwayY), .3, spot);

    if (reveal) {
      // Étiquettes du côté opposé à l'attaquant jugé, pour ne pas le masquer.
      final labelRight = s.target.x < pitchWidth / 2;
      _dashedLine(canvas, Offset(0, s.secondLastY), Offset(68, s.secondLastY),
          Paint()..color = c.card..strokeWidth = .4, 1.4, .8);
      _label(canvas, 'Avant-dernier défenseur', Offset(labelRight ? 67 : 1, s.secondLastY - 2.8), alignRight: labelRight);
      if (s.ball.y < s.secondLastY) {
        _dashedLine(canvas, Offset(0, s.ball.y), Offset(68, s.ball.y),
            Paint()..color = Colors.white.withValues(alpha: .8)..strokeWidth = .3, .6, .6);
        _label(canvas, 'Ballon', Offset(labelRight ? 67 : 1, s.ball.y - 2.8), alignRight: labelRight);
      }
    }

    // Trajectoire de la passe
    _dashedLine(canvas, Offset(s.passer.x, s.passer.y), Offset(s.target.x, s.target.y),
        Paint()..color = Colors.white.withValues(alpha: .85)..strokeWidth = .3, .9, .9);

    void player(Pt p, Color color) {
      canvas.drawCircle(Offset(p.x, p.y), 1.25, Paint()..color = color);
      canvas.drawCircle(
          Offset(p.x, p.y), 1.25, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = .35);
    }

    for (final d in [s.secondDefender, ...s.otherDefenders]) {
      player(d, c.red);
    }
    player(s.goalkeeper, c.card);
    for (final d in s.decoys) {
      player(d, c.attacker);
    }
    player(s.passer, c.attacker);
    player(s.target, c.attacker);

    canvas.drawCircle(Offset(s.ball.x, s.ball.y), .7, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.ball.x, s.ball.y), .7,
        Paint()..color = const Color(0xFF1B1606)..style = PaintingStyle.stroke..strokeWidth = .25);

    // Cercle autour de l'attaquant à juger
    final ring = Paint()
      ..color = c.card
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5;
    const segments = 16;
    for (var i = 0; i < segments; i += 1) {
      final start = i * 2 * pi / segments;
      canvas.drawArc(Rect.fromCircle(center: Offset(s.target.x, s.target.y), radius: 2.6), start, pi / segments * 1.1, false, ring);
    }

    _label(canvas, 'Ligne médiane', const Offset(67, halfwayY + .8), alignRight: true);
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset at, {bool alignRight = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 2.1, fontWeight: FontWeight.w700, fontFamily: kBody)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, alignRight ? at - Offset(tp.width, 0) : at);
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint, double dash, double gap) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = min(d + dash, total);
      canvas.drawLine(a + dir * d, a + dir * end, paint);
      d = end + gap;
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) => old.s != s || old.reveal != reveal || old.c != c;
}
