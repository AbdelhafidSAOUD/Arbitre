/// Correction automatique d'un rapport disciplinaire, selon la méthode de la
/// Direction technique de l'arbitrage (DTA) : plan en 5 temps, faits sans
/// jugement, propos exacts entre guillemets, écriture au présent.
///
/// La correction vérifie la structure et la forme du texte. Elle ne peut
/// pas juger l'exactitude des faits : c'est une aide, pas une note officielle.
library;

/// Un cas d'entraînement (anonymisé) et son rapport modèle en 5 parties.
class ReportCase {
  const ReportCase({
    required this.id,
    required this.title,
    required this.facts,
    required this.story,
    required this.model,
    required this.hasWords,
  });
  final String id, title, story;
  final List<(String, String)> facts;
  final List<String> model; // 5 paragraphes, un par partie du plan
  final bool hasWords; // des propos ont été tenus : ils doivent être cités

  factory ReportCase.fromJson(Map<String, dynamic> j) => ReportCase(
        id: j['id'] as String,
        title: j['title'] as String,
        story: j['story'] as String,
        hasWords: (j['has_words'] as bool?) ?? false,
        facts: [for (final f in j['facts'] as List) ((f as List)[0] as String, f[1] as String)],
        model: [for (final m in j['model'] as List) m as String],
      );
}

class ReportPart {
  const ReportPart(this.name, this.tip, this.test);
  final String name, tip;
  final bool Function(String) test;
}

RegExp _r(String p) => RegExp(p, caseSensitive: false, unicode: true);

/// Le plan en 5 temps de la DTA.
final reportParts = <ReportPart>[
  ReportPart(
    'Chapeau de présentation',
    'Commencez par une phrase qui résume tout : qui (numéro, équipe), quelle sanction, à quelle minute, pour quel motif.',
    (s) {
      final first = (s.trim().split('\n').first);
      final head = first.length > 260 ? first.substring(0, 260) : first;
      return _r(r'(exclusion|avertissement|exclu|averti)').hasMatch(head) && _r(r'(n°|numéro)\s?\d+').hasMatch(head);
    },
  ),
  ReportPart(
    'Situation dans le temps et l’espace',
    'Donnez la minute, le score, l’endroit précis (distance, côté, zone) et l’endroit où vous êtes placé.',
    (s) =>
        _r(r"\d{1,3}\s?(e|è|ème|eme|’|')").hasMatch(s) &&
        _r(r'(score|mène|partout|\d+\s?(but|-|à)\s?\d*)').hasMatch(s) &&
        _r(r'(surface|mètres|\d\s?m\b|côté|ligne|rond central|camp|banc|axe|terrain)').hasMatch(s),
  ),
  ReportPart(
    'Description des faits',
    'Qui fait quoi, avec quel geste, sur quelle partie du corps, ballon en jeu ou non. Les propos tels quels, entre guillemets.',
    (s) =>
        _r(r'(frappe|porte|donne|pousse|tacle|crie|dit|insulte|crache|repousse|touche|écarte|lance|bouscule|fonce|percute)')
            .hasMatch(s) &&
        _r(r'(poing|visage|bras|main|pied|tête|jambe|propos|«|")').hasMatch(s),
  ),
  ReportPart(
    'Sanctions et mise en œuvre',
    'Écrivez la sanction, son motif réglementaire (Loi 12) et comment vous l’appliquez (carton présenté, attitude du joueur).',
    (s) =>
        _r(r"(carton rouge|carton jaune|j[’']exclus|j[’']avertis|exclu|averti)").hasMatch(s) &&
        _r(r'(comportement violent|faute grossière|propos injurieux|propos grossiers|propos blessants|annihil|anéanti|occasion de but|comportement antisportif|brutalité)')
            .hasMatch(s),
  ),
  ReportPart(
    'Reprise du jeu et informations diverses',
    'Terminez par la reprise (coup franc direct, penalty, reprise prévue…) et les suites : soins, blessure, attitude, incidents.',
    (s) =>
        _r(r'(reprise|reprend|reprendre)').hasMatch(s) &&
        _r(r"(coup franc|penalty|balle à terre|rentrée de touche|coup de pied|corner|coup d’envoi|coup d'envoi|reprise prévue)")
            .hasMatch(s),
  ),
];

/// Mots qui jugent au lieu de décrire.
const judgmentWords = [
  'agressif', 'agressive', 'fou', 'folle', 'honteux', 'honteuse', 'inadmissible', 'scandaleux', 'scandaleuse',
  'lâche', 'débile', 'je pense', 'il me semble', 'peut-être', 'apparemment', 'sauvage', 'voyou', 'brute',
  'énervé', 'énervée', 'nerveux', 'mauvais esprit', 'sans raison', 'pour rien', 'visiblement', 'hystérique',
];

final _conjugation = <(RegExp, String)>[
  (_r(r"j[’']exclue?(?![a-zàâçéèêëîïôûùüÿ])"), '« j’exclu » s’écrit « j’exclus »'),
  (_r(r"j[’']avertie?(?![a-zàâçéèêëîïôûùüÿ])"), '« j’averti » s’écrit « j’avertis »'),
  (_r(r'(est|a été)\s+exclut\b'), '« il est exclut » s’écrit « il est exclu »'),
  (_r(r'(est|a été)\s+avertit\b'), '« il est avertit » s’écrit « il est averti »'),
];

final _pastForms = _r(
    r"(a été|avait|était|s[’']est|ai (arrêté|exclu|averti|sifflé|vu|présenté|accordé)|a (frappé|donné|porté|dit|crié|poussé|touché|insulté|repoussé))");

final _personName = RegExp(r"(M\.|Mme|Monsieur|Madame)\s+(?!\[)[A-ZÀ-Ý][A-Za-zÀ-ÿ’'-]+(\s+[A-ZÀ-Ý][A-Za-zÀ-ÿ’'-]+)?");
final _licence = RegExp(r'\b\d{8,}\b');

class ReportFeedback {
  const ReportFeedback({
    required this.parts,
    required this.quotes,
    required this.judgments,
    required this.conjugation,
    required this.pastForms,
    required this.personalData,
    required this.words,
    required this.score,
  });
  final List<bool> parts; // une valeur par partie du plan
  final bool quotes;
  final List<String> judgments;
  final List<String> conjugation;
  final int pastForms;
  final bool personalData;
  final int words;
  final int score; // sur 20

  static const passMark = 6; // note éliminatoire de l'examen DTA
}

int wordCount(String s) => s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

/// Corrige un rapport. Barème indicatif sur 20 :
/// 3 points par partie du plan (15), 2 pour les propos cités (si le cas en
/// comporte), 1 sans jugement de valeur, 1 sans faute sur avertir/exclure,
/// 1 pour l'écriture au présent. Un texte de moins de 40 mots est plafonné à 6.
ReportFeedback analyseReport(String text, ReportCase c) {
  final parts = [for (final p in reportParts) p.test(text)];
  final quotes = RegExp(r'[«"“][^»"”]{5,}[»"”]').hasMatch(text);
  final lower = text.toLowerCase();
  final judgments = [
    for (final w in judgmentWords)
      if (RegExp('(^|[^a-zàâçéèêëîïôûùüÿ])${RegExp.escape(w)}' r'([^a-zàâçéèêëîïôûùüÿ]|$)').hasMatch(lower)) w,
  ];
  final conj = [
    for (final (re, msg) in _conjugation)
      if (re.hasMatch(text)) msg,
  ];
  final past = _pastForms.allMatches(text).length;
  final words = wordCount(text);
  var score = parts.where((x) => x).length * 3;
  if (!c.hasWords || quotes) score += 2;
  if (judgments.isEmpty) score += 1;
  if (conj.isEmpty) score += 1;
  if (past < 2) score += 1;
  if (words < 40 && score > 6) score = 6;
  return ReportFeedback(
    parts: parts,
    quotes: quotes,
    judgments: judgments,
    conjugation: conj,
    pastForms: past,
    personalData: _personName.hasMatch(text) || _licence.hasMatch(text),
    words: words,
    score: score,
  );
}

/// Remplace les noms et numéros de licence par des marqueurs neutres.
String anonymiseReport(String text) => text
    .replaceAllMapped(_personName, (m) => '${m.group(1)} [NOM Prénom]')
    .replaceAll(_licence, '[licence]');
