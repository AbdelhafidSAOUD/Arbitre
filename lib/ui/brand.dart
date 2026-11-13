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
    // Trois cartons qui montent : l'arbitrage et la progression.
    final cards = Semantics(
      label: 'Sifflet Académie',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: const Color(0xFF13203A), borderRadius: BorderRadius.circular(size * .22)),
        child: CustomPaint(painter: _LogoPainter(c.card, c.red)),
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
    RRect card(double x, double y, double w, double h) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x * u, y * u, w * u, h * u), Radius.circular(3.5 * u));
    canvas.drawRRect(card(16, 52, 20, 28), Paint()..color = yellow.withValues(alpha: .55));
    canvas.drawRRect(card(40, 38, 20, 42), Paint()..color = yellow);
    canvas.drawRRect(card(64, 20, 20, 60), Paint()..color = red);
    canvas.drawRRect(card(12, 84, 76, 4), Paint()..color = const Color(0xFF2F8D56));
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.yellow != yellow || old.red != red;
}
