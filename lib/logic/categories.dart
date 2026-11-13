/// Catégories officielles d'arbitres, par pays.
///
/// La liste n'est pas figée : un arbitre peut ajouter sa catégorie ou son
/// niveau s'il ne les trouve pas. Sa proposition est enregistrée sur son
/// profil tout de suite, et devient visible pour les autres arbitres une
/// fois validée par un administrateur (table `category_suggestions`).
class RefCategory {
  const RefCategory(this.id, this.name, this.subtitle, [this.levels = const [], this.tier = Tier.confirmed]);
  final String id, name, subtitle;
  final List<String> levels;
  final Tier tier;
}

/// Expérience supposée, pour adapter la difficulté des questions.
enum Tier { beginner, confirmed, expert }

const countries = <String, String>{
  'FR': 'France',
  'MA': 'Maroc',
};

const customCategoryId = 'autre';

const _fr = <RefCategory>[
  RefCategory('jad', 'Jeune arbitre de district (JAD)', 'Compétitions jeunes de district', [], Tier.beginner),
  RefCategory('jal', 'Jeune arbitre de ligue (JAL)', 'Compétitions régionales de jeunes',
      ['JAR stagiaire', 'JAR', 'JAL 2', 'JAL 1'], Tier.beginner),
  RefCategory('jaf', 'Jeune arbitre fédéral (JAF)', 'Championnats nationaux de jeunes', ['Candidat JAF', 'JAF']),
  RefCategory('district', 'Arbitre de district', 'Seniors, compétitions de district', ['D4', 'D3', 'D2', 'D1']),
  RefCategory('ligue', 'Arbitre de ligue', 'Seniors, compétitions régionales',
      ['R3 stagiaire', 'R3', 'R2 stagiaire', 'R2', 'R1']),
  RefCategory('regional', 'Arbitre régional élite', 'Haut niveau de la ligue', ['R1 promo', 'Candidat F5'], Tier.expert),
  RefCategory('federal', 'Arbitre fédéral', 'Compétitions nationales', ['F5', 'F4', 'F3', 'F2', 'F1'], Tier.expert),
  RefCategory('formateur', 'Formateur', 'Forme les arbitres (CDA, CRA)', [], Tier.expert),
  RefCategory('observateur', 'Observateur', 'Évalue les arbitres en match', [], Tier.expert),
];

const _ma = <RefCategory>[
  RefCategory('ma_jeune', 'Jeune arbitre', 'Catégories jeunes', [], Tier.beginner),
  RefCategory('ma_ligue', 'Arbitre de ligue régionale', 'Championnats de ligue'),
  RefCategory('ma_national', 'Arbitre national', 'Compétitions nationales', [], Tier.expert),
  RefCategory('formateur', 'Formateur', 'Encadrement des arbitres', [], Tier.expert),
  RefCategory('observateur', 'Observateur', 'Évalue les arbitres en match', [], Tier.expert),
];

List<RefCategory> builtInCategories(String country) => country == 'MA' ? _ma : _fr;

/// Identifiants acceptés par la base (voir la migration).
final allCategoryIds = {for (final c in [..._fr, ..._ma]) c.id, customCategoryId};

/// Anciennes valeurs du profil (version 1), converties à la lecture.
String migrateLevel(String level) => switch (level) {
      'jeune' => 'jad',
      _ => allCategoryIds.contains(level) ? level : 'district',
    };

RefCategory? findCategory(String country, String id) {
  for (final c in builtInCategories(country)) {
    if (c.id == id) return c;
  }
  return null;
}

Tier tierFor(String level) {
  for (final c in [..._fr, ..._ma]) {
    if (c.id == level) return c.tier;
  }
  return Tier.confirmed;
}

/// Proposition d'un arbitre : une catégorie, ou un niveau dans une catégorie.
class CategorySuggestion {
  const CategorySuggestion({
    required this.id,
    required this.country,
    required this.kind,
    required this.label,
    this.categoryId,
    this.status = 'en_attente',
  });
  final String id, country, kind, label; // kind : categorie | niveau
  final String? categoryId; // pour un niveau : la catégorie concernée
  final String status; // en_attente | validee | refusee

  bool get validated => status == 'validee';

  static const maxLength = 60;

  Map<String, dynamic> toRow() => {
        'id': id,
        'country': country,
        'kind': kind,
        'category_id': categoryId,
        'label': label,
      };

  Map<String, dynamic> toJson() => {...toRow(), 'status': status};

  factory CategorySuggestion.fromRow(Map<String, dynamic> j) => CategorySuggestion(
        id: j['id'] as String,
        country: j['country'] as String,
        kind: j['kind'] as String,
        label: j['label'] as String,
        categoryId: j['category_id'] as String?,
        status: (j['status'] as String?) ?? 'en_attente',
      );
}

/// Nettoie un libellé saisi : espaces superflus, longueur maximale.
String cleanLabel(String s) {
  final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
  return t.length > CategorySuggestion.maxLength ? t.substring(0, CategorySuggestion.maxLength) : t;
}

/// Catégories proposées à l'écran : les officielles, puis celles ajoutées
/// par des arbitres (validées, ou proposées par l'utilisateur lui-même).
List<({String id, String name, String subtitle, bool added})> categoryChoices(
  String country,
  Iterable<CategorySuggestion> suggestions,
) {
  final seen = <String>{};
  return [
    for (final c in builtInCategories(country)) (id: c.id, name: c.name, subtitle: c.subtitle, added: false),
    for (final s in suggestions)
      if (s.country == country && s.kind == 'categorie' && seen.add(s.label.toLowerCase()))
        (
          id: 'sugg:${s.label}',
          name: s.label,
          subtitle: s.validated ? 'Ajoutée par un arbitre' : 'Votre proposition · en vérification',
          added: true,
        ),
  ];
}

/// Niveaux proposés pour une catégorie : les officiels puis les ajoutés.
List<String> levelChoices(String country, String categoryId, String? customCategory,
    Iterable<CategorySuggestion> suggestions) {
  final base = findCategory(country, categoryId)?.levels ?? const <String>[];
  final key = categoryId == customCategoryId ? 'sugg:${customCategory ?? ''}' : categoryId;
  final out = [...base];
  for (final s in suggestions) {
    if (s.country == country && s.kind == 'niveau' && s.categoryId == key && !out.contains(s.label)) out.add(s.label);
  }
  return out;
}
