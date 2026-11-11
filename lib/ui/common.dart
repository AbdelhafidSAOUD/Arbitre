import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Donne accès à l'état de l'application et reconstruit l'interface
/// quand il change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

enum Tone { ok, mid, ko, none }

Tone toneForPercent(int? p) => p == null
    ? Tone.none
    : p >= 75
        ? Tone.ok
        : p >= 50
            ? Tone.mid
            : Tone.ko;

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = Tone.none});
  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final (bg, fg) = switch (tone) {
      Tone.ok => (c.pitchSoft, c.pitch),
      Tone.mid => (c.cardSoft, c.ink),
      Tone.ko => (c.redSoft, c.red),
      Tone.none => (c.surface2, c.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg, fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: context.sc.muted),
      );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26, bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(text.toUpperCase(), style: Theme.of(context).textTheme.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

class Headline extends StatelessWidget {
  const Headline({super.key, required this.eyebrow, required this.title, this.subtitle});
  final String eyebrow, title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(eyebrow),
          const SizedBox(height: 2),
          Text(title.toUpperCase(), style: Theme.of(context).textTheme.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: TextStyle(color: context.sc.muted)),
          ],
        ],
      );
}

/// Bloc blanc à bordure fine.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color, borderColor;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        // Material (et non une simple décoration) pour que les cases à cocher
        // et effets d'appui posés dessus restent visibles.
        child: Material(
          color: color ?? context.sc.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: borderColor ?? context.sc.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Liste en bloc, lignes séparées par un filet.
class ListBox extends StatelessWidget {
  const ListBox({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.sc.surface,
          border: Border.all(color: context.sc.line),
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(),
              children[i],
            ],
          ],
        ),
      );
}

class Row2 extends StatelessWidget {
  const Row2({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.strike = false});
  final Widget? leading, trailing;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool strike;
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: strike ? c.muted : c.ink,
                        decoration: strike ? TextDecoration.lineThrough : null,
                      )),
                  if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, color: c.muted)),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class LawNumber extends StatelessWidget {
  const LawNumber(this.law, {super.key, this.highlight = false});
  final int law;
  final bool highlight;
  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight ? c.card : c.surface2,
        border: Border.all(color: highlight ? c.card : c.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$law', style: TextStyle(fontFamily: kDisplay, fontWeight: FontWeight.w800, fontSize: 19, color: highlight ? c.onCard : c.ink)),
    );
  }
}

/// Grande tuile d'action (accueil, entraînement).
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final fg = primary ? c.onCard : c.ink;
    final iconBox = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primary ? Colors.black.withValues(alpha: .1) : c.pitchSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 21, color: primary ? c.onCard : c.pitch),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title.toUpperCase(), style: TextStyle(fontFamily: kDisplay, fontSize: 19, fontWeight: FontWeight.w800, height: 1.05, color: fg)),
        const SizedBox(height: 3),
        Text(subtitle, style: TextStyle(fontSize: 13, height: 1.3, color: primary ? c.onCard.withValues(alpha: .85) : c.muted)),
      ],
    );
    return Opacity(
      opacity: onTap == null ? .55 : 1,
      child: Material(
        color: primary ? c.card : c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: primary ? c.card : c.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: primary
                ? Row(children: [iconBox, const SizedBox(width: 14), Expanded(child: texts), if (onTap != null) Icon(Icons.arrow_forward, color: fg)])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [iconBox, const SizedBox(height: 8), texts]),
          ),
        ),
      ),
    );
  }
}

/// Grille de tuiles à deux colonnes, de hauteur égale par ligne.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
    }
    return Column(children: [for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), rows[i]]]);
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Marges de page standard.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: children,
      );
}
