import 'package:material_ui/material_ui.dart';

import '../logic/categories.dart';
import '../theme.dart';
import 'common.dart';

/// Pays, catégorie officielle, niveau précis et fonction de l'arbitre.
class RefereeIdentity {
  const RefereeIdentity({
    required this.country,
    required this.level,
    this.levelDetail,
    this.customCategory,
    required this.role,
    required this.alsoOther,
  });
  final String country, level, role;
  final String? levelDetail, customCategory;
  final bool alsoOther;

  /// Clé de la catégorie dans la liste affichée.
  String get choiceId => level == customCategoryId ? 'sugg:${customCategory ?? ''}' : level;

  RefereeIdentity copyWith({
    String? country,
    String? level,
    String? Function()? levelDetail,
    String? Function()? customCategory,
    String? role,
    bool? alsoOther,
  }) =>
      RefereeIdentity(
        country: country ?? this.country,
        level: level ?? this.level,
        levelDetail: levelDetail == null ? this.levelDetail : levelDetail(),
        customCategory: customCategory == null ? this.customCategory : customCategory(),
        role: role ?? this.role,
        alsoOther: alsoOther ?? this.alsoOther,
      );
}

/// Formulaire réutilisé à l'inscription et dans le profil.
class RefereeIdentityForm extends StatelessWidget {
  const RefereeIdentityForm({super.key, required this.value, required this.onChanged});
  final RefereeIdentity value;
  final ValueChanged<RefereeIdentity> onChanged;

  Future<String?> _ask(BuildContext context, String title, String label, String hint) =>
      showDialog<String>(context: context, builder: (_) => _TextPrompt(title: title, label: label, hint: hint));

  Future<void> _addCategory(BuildContext context) async {
    final s = AppScope.read(context);
    final label = cleanLabel(await _ask(context, 'Ajouter ma catégorie', 'Nom de la catégorie', 'ex. Arbitre futsal de ligue') ?? '');
    if (label.isEmpty) return;
    s.proposeCategory(country: value.country, kind: 'categorie', label: label);
    onChanged(value.copyWith(level: customCategoryId, customCategory: () => label, levelDetail: () => null));
  }

  Future<void> _addLevel(BuildContext context) async {
    final s = AppScope.read(context);
    final label = cleanLabel(await _ask(context, 'Ajouter un niveau', 'Niveau', 'ex. R2 stagiaire') ?? '');
    if (label.isEmpty) return;
    s.proposeCategory(country: value.country, kind: 'niveau', label: label, categoryId: value.choiceId);
    onChanged(value.copyWith(levelDetail: () => label));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final choices = categoryChoices(value.country, s.allSuggestions);
    final levels = levelChoices(value.country, value.level, value.customCategory, s.allSuggestions);
    final other = value.role == 'central' ? 'assistant' : 'central';

    Widget option({required bool selected, required String title, String? subtitle, String? tag, required VoidCallback onTap}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Semantics(
            selected: selected,
            button: true,
            child: Material(
              color: selected ? c.pitchSoft : c.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: selected ? c.pitch : c.line, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: c.ink)),
                        if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 13, color: c.muted)),
                      ]),
                    ),
                    if (tag != null) ...[
                      const SizedBox(width: 8),
                      Pill(tag, tone: Tone.mid),
                    ],
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: c.pitch, size: 20),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Eyebrow('Pays'),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: [for (final e in countries.entries) ButtonSegment(value: e.key, label: Text(e.value))],
        selected: {value.country},
        onSelectionChanged: (v) => onChanged(value.copyWith(
          country: v.first,
          level: builtInCategories(v.first).first.id,
          levelDetail: () => null,
          customCategory: () => null,
        )),
      ),
      const SizedBox(height: 18),
      const Eyebrow('Catégorie officielle'),
      const SizedBox(height: 4),
      Text('Votre catégorie actuelle. Elle ne change pas avec les points gagnés dans l’application.',
          style: TextStyle(fontSize: 13, color: c.muted)),
      const SizedBox(height: 10),
      for (final ch in choices)
        option(
          selected: ch.id == value.choiceId,
          title: ch.name,
          subtitle: ch.subtitle,
          tag: ch.added ? 'Ajoutée' : null,
          onTap: () => onChanged(ch.id.startsWith('sugg:')
              ? value.copyWith(level: customCategoryId, customCategory: () => ch.name, levelDetail: () => null)
              : value.copyWith(level: ch.id, customCategory: () => null, levelDetail: () => null)),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _addCategory(context),
          icon: const Icon(Icons.add),
          label: const Text('Ma catégorie n’est pas dans la liste'),
        ),
      ),
      const SizedBox(height: 10),
      const Eyebrow('Niveau précis (facultatif)'),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in levels)
          ChoiceChip(
            label: Text(l),
            selected: value.levelDetail == l,
            onSelected: (on) => onChanged(value.copyWith(levelDetail: () => on ? l : null)),
          ),
        if (value.levelDetail != null && !levels.contains(value.levelDetail))
          ChoiceChip(
            label: Text(value.levelDetail!),
            selected: true,
            onSelected: (_) => onChanged(value.copyWith(levelDetail: () => null)),
          ),
        ActionChip(avatar: const Icon(Icons.add, size: 18), label: const Text('Ajouter un niveau'), onPressed: () => _addLevel(context)),
      ]),
      const SizedBox(height: 20),
      const Eyebrow('Fonction principale'),
      const SizedBox(height: 10),
      option(
        selected: value.role != 'assistant',
        title: 'Arbitre central',
        subtitle: 'Vous dirigez le match',
        onTap: () => onChanged(value.copyWith(role: 'central')),
      ),
      option(
        selected: value.role == 'assistant',
        title: 'Arbitre assistant',
        subtitle: 'Vous tenez le drapeau',
        onTap: () => onChanged(value.copyWith(role: 'assistant')),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: value.alsoOther,
        onChanged: (v) => onChanged(value.copyWith(alsoOther: v ?? false)),
        title: Text('J’officie aussi comme arbitre $other'),
        subtitle: const Text('Les séances incluront les deux fonctions'),
      ),
    ]);
  }
}

/// Petite fenêtre de saisie. Elle possède son champ de texte, libéré
/// seulement quand la fenêtre a fini de se fermer.
class _TextPrompt extends StatefulWidget {
  const _TextPrompt({required this.title, required this.label, required this.hint});
  final String title, label, hint;
  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLength: CategorySuggestion.maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: widget.label, hintText: widget.hint),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          Text(
            'Elle sera proposée aux autres arbitres après vérification. N’y mettez aucune information personnelle.',
            style: TextStyle(fontSize: 13, color: context.sc.muted),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(style: compactButton, onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Ajouter')),
        ],
      );
}
