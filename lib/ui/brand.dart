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
    final cards = SizedBox(
      width: size,
      height: size,
      child: Stack(children: [
        Positioned(
          left: size * .2,
          top: size * .1,
          child: Transform.rotate(
            angle: -10 * pi / 180,
            child: Container(width: size * .42, height: size * .58, decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(size * .08))),
          ),
        ),
        Positioned(
          left: size * .38,
          top: size * .26,
          child: Transform.rotate(
            angle: 8 * pi / 180,
            child: Container(width: size * .42, height: size * .58, decoration: BoxDecoration(color: c.red, borderRadius: BorderRadius.circular(size * .08))),
          ),
        ),
      ]),
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
