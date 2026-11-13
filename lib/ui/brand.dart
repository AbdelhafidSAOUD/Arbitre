import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Logo : un carton jaune et un carton rouge superposés, et le nom.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    // Le rond central vu du dessus, cartons jaune et rouge au point d'engagement.
    final cards = Semantics(
      label: 'Sifflet Académie',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: SizedBox(width: size, height: size, child: CustomPaint(painter: _LogoPainter(c.card, c.red))),
      ),
    );
    if (!showName) return cards;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      cards,
      SizedBox(width: size * .3),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('SIFFLET',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontFamily: kDisplay, fontSize: size * .8, fontWeight: FontWeight.w800, height: 1, color: c.ink)),
          Text('ACADÉMIE DES ARBITRES',
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: max(10, size * .36), fontWeight: FontWeight.w600, letterSpacing: 1, color: c.muted)),
        ]),
      ),
    ]);
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.yellow, this.red);
  final Color yellow, red;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    const white = Color(0xFFF3F6FB);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1D7447));
    canvas.drawRect(Rect.fromLTWH(0, 0, 50 * u, 100 * u), Paint()..color = const Color(0xFF2A804E));
    final line = Paint()
      ..color = white
      ..strokeWidth = 3 * u
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(50 * u, 0), Offset(50 * u, 100 * u), line);
    canvas.drawCircle(Offset(50 * u, 50 * u), 27 * u, line);
    void card(double x, double y, Color color, double degrees) {
      final center = Offset((x + 8.5) * u, (y + 12.5) * u);
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(degrees * pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 17 * u, height: 25 * u), Radius.circular(3 * u)),
        Paint()..color = color,
      );
      canvas.restore();
    }

    card(35, 36, yellow, -10);
    card(48, 40, red, 10);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.yellow != yellow || old.red != red;
}
