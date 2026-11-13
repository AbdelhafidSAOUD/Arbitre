# Sifflet Académie

Application mobile (Android et iPhone) pour accompagner les arbitres de football :
quiz sur les 17 Lois du Jeu, simulateur de hors-jeu, formation, révisions espacées,
examen blanc et suivi de progression.

## Fonctionnalités

| Domaine | Ce que fait l'application |
|---|---|
| Profil | Pays (France, Maroc), catégorie officielle (JAD, JAL, JAF, district, ligue, régional, fédéral, formateur, observateur) et niveau précis (R2, F4…), fonction principale (central ou assistant), objectif. L'arbitre peut ajouter sa catégorie ou son niveau ; après validation, ils sont proposés aux autres. Le palier d'entraînement (XP) est distinct de la catégorie officielle. |
| Programme du jour | 3 à 4 tâches calculées selon l'objectif et les points faibles, cochées automatiquement. |
| Quiz | 92 questions (situations de match et connaissances), difficulté 1 à 3, explication et loi de référence après chaque réponse. Une partie vient d'examens de ligue et fédéraux, mis à jour aux Lois 2025/26. |
| Format examen | 10 cas où l'on coche toutes les décisions (arrêt, sanction et motif, reprise, rapport), notés comme à l'examen : 0,25 point par élément oublié ou en trop. |
| Rapport disciplinaire | Atelier de rédaction selon la méthode de la DTA (plan en 5 temps, CQQCOQP, présent) : note indicative sur 20, conseils, rapport modèle annoté, anonymisation des noms. |
| Simulateur de hors-jeu | Situations générées à l'infini sur un terrain à l'échelle ; correction avec la ligne de l'avant-dernier défenseur. |
| Mode match | 15 secondes par décision. |
| Examen blanc | 30 questions en 20 minutes, correction à la fin, seuil de 80 %. |
| Révisions espacées | Une erreur revient le lendemain, puis à 2, 4, 8 et 16 jours. |
| Séance en salle | Pour les formateurs : projeter une question, faire voter, révéler. |
| Formation | Fiches des 17 lois réparties en 5 parcours, validation à 75 %. |
| Matchs | Matchs à venir avec un objectif ; débriefing après le match (satisfaction, ressenti, notes sur 6 critères, cartons, points à travailler, objectif suivant) ; courbe de satisfaction et exercices liés aux points faibles. |
| Physique | Tests 2025/26 de la CRA selon la fonction et le niveau (sprint 40 m, S.D.S., sprint 30 m, C.O.D.A., A.R.I.E.T.), schémas, séance S.D.S. guidée au chrono, journal des résultats. |
| Progression | Maîtrise par loi, examens, notes aux cas d'examen et aux rapports, badges (depuis le profil). |
| Données personnelles | Consentement versionné, accord parental sous 15 ans, export, suppression du compte. |
| Hors ligne | Tout fonctionne sans réseau ; synchronisation automatique au retour de la connexion. |

## Architecture

```
 Téléphone (Flutter)                          Supabase (serveur, région UE)
┌──────────────────────────────┐   HTTPS   ┌────────────────────────────────┐
│ Interface (lib/ui)           │           │ Comptes : code par e-mail       │
│ État central (lib/state)     │◄────────► │ PostgreSQL + règles RLS         │
│ Stockage local + file d'envoi│           │ Fonction delete-account         │
└──────────────────────────────┘           └────────────────────────────────┘
```

- **Toute action s'applique d'abord sur le téléphone**, puis part dans une file
  d'envoi conservée localement. L'application ne dépend jamais du réseau.
- **Le contenu (questions, fiches) vit sur le serveur** et une copie est livrée avec
  l'application. Mettre à jour les questions ne demande pas de nouvelle version.
- **Sécurité** : chaque table de données personnelles est protégée par des règles
  RLS. Un utilisateur ne peut lire ni modifier les données d'un autre, même en
  contournant l'application. Voir [docs/SECURITE.md](docs/SECURITE.md).

```
lib/
  main.dart                 démarrage
  config.dart               configuration (serveur, politique de confidentialité)
  theme.dart                couleurs et typographie
  models/                   questions, fiches, profil, matchs…
  logic/                    hors-jeu, révisions espacées, sélection, niveaux, badges
  data/                     stockage local, synchronisation, accès Supabase
  state/app_state.dart      état central
  ui/                       écrans
assets/content/             questions et fiches embarquées
supabase/migrations/        schéma de la base et règles de sécurité
supabase/functions/         suppression de compte
supabase/seed.sql           contenu initial (généré)
supabase/tests/             tests de sécurité de la base
tool/                       génération du contenu, tests de la base
```

## Démarrer en local (sans serveur)

Prérequis : [Flutter](https://docs.flutter.dev/get-started/install) 3.50 ou plus récent.

```bash
flutter pub get
```

```bash
flutter run
```

Sans configuration, l'application démarre en **mode local** : pas de compte, données
gardées sur l'appareil uniquement. Pratique pour découvrir l'application.

## Brancher le serveur

1. Suivez [docs/MISE_EN_SERVICE.md](docs/MISE_EN_SERVICE.md) pour créer le projet Supabase.
2. Copiez `config/dev.example.json` en `config/dev.json` et remplissez-le.
3. Lancez :

```bash
flutter run --dart-define-from-file=config/dev.json
```

## Tests

```bash
flutter analyze
```

```bash
flutter test
```

Tests de la base (schéma, contenu, règles de sécurité) sur un PostgreSQL local :

```bash
PGUSER=postgres ./tool/test_database.sh
```

Ces trois vérifications, plus la compilation Android, tournent automatiquement sur
GitHub à chaque envoi (`.github/workflows/ci.yml`).

## Modifier les questions

Pendant le développement, modifiez `assets/content/questions.json`, puis :

```bash
dart run tool/generate_seed.dart
```

et exécutez `supabase/seed.sql` sur le serveur. En production, vous pouvez aussi
modifier les questions directement dans le tableau de bord Supabase (table
`questions`) : les téléphones reçoivent la nouvelle version à la synchronisation
suivante.

## Publier

Voir [docs/PUBLICATION.md](docs/PUBLICATION.md) (Google Play et App Store).

## Avertissement sur le contenu

Les questions et fiches sont des résumés pédagogiques rédigés pour l'application,
basés sur les Lois du Jeu 2025/26. Le texte officiel appartient à l'IFAB. Faites
relire le contenu par un formateur ou une commission d'arbitrage avant diffusion.
