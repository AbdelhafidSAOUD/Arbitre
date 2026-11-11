# Sécurité et protection des données

## Mesures en place

| Risque | Protection | Où |
|---|---|---|
| Un utilisateur lit les données d'un autre | Règles RLS sur chaque table : `auth.uid() = user_id` | `supabase/migrations/` |
| Un utilisateur écrit au nom d'un autre | Même règle en écriture (`with check`) | idem |
| Un visiteur non connecté interroge l'API | Tous les droits retirés au rôle `anon` | fin de la migration |
| Modification de l'historique des réponses | Aucune règle de modification ni de suppression sur `answers` et `sessions` | idem |
| Ajout de fausses questions | Écriture du contenu réservée aux administrateurs (`is_admin()`) | idem |
| Données incohérentes ou trop longues | Contraintes `check` (notes 0–20, longueurs, valeurs autorisées) | idem |
| Vol de la clé d'administration | La clé secrète n'existe que dans la fonction serveur `delete-account` | `supabase/functions/` |
| Interception réseau | HTTPS uniquement | Supabase |
| Mot de passe faible ou réutilisé | Pas de mot de passe : code à usage unique par e-mail | `lib/ui/auth_screen.dart` |
| Téléphone partagé | Données locales effacées à la déconnexion ; sauvegarde Android désactivée (`allowBackup=false`) | `lib/state/app_state.dart` |
| Données restantes après départ | Suppression du compte en cascade sur toutes les tables | migration + fonction |

Ces règles sont **testées automatiquement** sur une vraie base PostgreSQL
(`supabase/tests/securite_rls.sql`) : un utilisateur B ne voit, ne modifie ni ne
supprime aucune donnée d'un utilisateur A, un visiteur anonyme n'a accès à rien, et
la suppression du compte efface tout.

## RGPD

| Exigence | Mise en œuvre |
|---|---|
| Hébergement | Projet Supabase en région UE |
| Minimisation | Prénom facultatif, année de naissance seulement (pas la date complète), aucune localisation |
| Consentement | Acceptation de la politique de confidentialité, datée et versionnée (`privacy_version`). Changer `AppConfig.privacyVersion` redemande l'accord à tous |
| Mineurs | Moins de 15 ans : e-mail d'un parent et confirmation de son accord (article 8 RGPD, seuil français) |
| Droit d'accès et portabilité | Profil → « Voir et copier mes données » |
| Droit à l'effacement | Profil → « Supprimer mon compte » |
| Droit de rectification | Profil modifiable ; matchs modifiables et supprimables |

À faire de votre côté :

- rédiger et publier la politique de confidentialité (modèle fourni) ;
- tenir le **registre des traitements** (modèle simplifié sur le site de la CNIL) ;
- signer l'accord de traitement des données (DPA) de Supabase et de votre fournisseur
  d'e-mails (disponibles dans leurs tableaux de bord) ;
- en dehors de l'UE, vérifier la loi locale (par exemple loi 18-07 en Algérie,
  loi 09-08 au Maroc, qui peuvent demander une déclaration à l'autorité nationale).

## Limites connues

- **Points d'expérience** : ils sont calculés sur le téléphone. Un utilisateur
  technique pourrait gonfler ses propres points. Sans conséquence tant qu'il n'y a
  pas de classement entre arbitres ; si vous en ajoutez un, déplacez ce calcul dans
  une fonction serveur.
- **Accord parental** : il est déclaratif (case cochée et e-mail du parent). Pour
  une vérification forte, envoyez un e-mail de confirmation au parent depuis une
  fonction serveur.
- **Stockage local** : les données hors ligne sont dans le stockage privé de
  l'application, non chiffré en plus de la protection du système. Elles ne
  contiennent ni mot de passe ni donnée sensible ; la session de connexion est
  gérée par `supabase_flutter`.

## Bonnes pratiques d'exploitation

- Activer la double authentification sur les comptes Supabase, Google Play Console,
  App Store Connect et GitHub.
- Ne jamais versionner `config/*.json`, `android/key.properties` ni les fichiers `.jks`
  (déjà exclus par `.gitignore`).
- Plan Pro de Supabase en production pour les sauvegardes quotidiennes.
- Relire le « Security Advisor » du tableau de bord Supabase après chaque
  modification du schéma.
