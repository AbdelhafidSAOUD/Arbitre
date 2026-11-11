# Mise en service du serveur (Supabase)

Comptez environ une heure. Tout se fait depuis le navigateur ; la ligne de commande
Supabase est facultative.

## 1. Créer le projet

1. Créez un compte sur [supabase.com](https://supabase.com).
2. **New project** :
   - Nom : `sifflet-academie`
   - Région : **Europe (Frankfurt ou Paris si proposé)**. C'est important pour le RGPD : les données restent dans l'Union européenne.
   - Mot de passe de la base : générez-le et rangez-le dans un gestionnaire de mots de passe. L'application n'en a pas besoin.
3. Le plan gratuit suffit pour démarrer. Passez au plan Pro (environ 25 $/mois) avant
   le lancement public : sauvegardes quotidiennes et pas de mise en pause du projet.

## 2. Créer les tables et les règles de sécurité

1. Menu **SQL Editor** → **New query**.
2. Collez le contenu de `supabase/migrations/20261111000000_schema_initial.sql`, puis **Run**.
3. Nouvelle requête : collez `supabase/seed.sql`, puis **Run** (57 questions, 17 fiches).
4. Menu **Table Editor** : vérifiez que les tables `profiles`, `questions`, `answers`,
   `reviews`, `sessions`, `matches`, `badges` et `lessons` existent, chacune avec
   le badge « RLS enabled ».

Avec la ligne de commande Supabase, l'équivalent est :

```bash
supabase link --project-ref VOTRE_REF
```

```bash
supabase db push
```

## 3. Configurer la connexion par code e-mail

Menu **Authentication** :

1. **Sign In / Providers → Email** : activé. Laissez « Confirm email » activé.
2. **Emails → Templates → Magic Link** : l'application utilise le **code** et non le
   lien. Remplacez le modèle par exemple par :

   ```html
   <h2>Votre code Sifflet Académie</h2>
   <p>Saisissez ce code dans l'application :</p>
   <p style="font-size:28px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
   <p>Il est valable une heure. Si vous n'avez rien demandé, ignorez cet e-mail.</p>
   ```

   Faites de même pour le modèle **Confirm signup** (premier envoi à une nouvelle adresse).
3. **Emails → SMTP Settings** : **obligatoire en production**. Le service d'envoi
   intégré à Supabase est limité à quelques e-mails par heure et réservé aux
   tests. Branchez un fournisseur (Brevo, Resend, Mailjet, Amazon SES…) avec une
   adresse d'expédition de votre domaine, par exemple `noreply@votre-domaine.fr`.
4. **Rate Limits** : gardez les valeurs par défaut (protection contre les abus).

## 4. Déployer la suppression de compte

La suppression du compte depuis l'application passe par une fonction serveur, car
elle demande des droits d'administration qui ne doivent jamais être dans l'application.

Avec la ligne de commande Supabase :

```bash
supabase functions deploy delete-account
```

Sans la ligne de commande : menu **Edge Functions → Deploy a new function → Via
Editor**, nommez-la `delete-account` et collez le contenu de
`supabase/functions/delete-account/index.ts`.

## 5. Récupérer la configuration de l'application

Menu **Project Settings → API Keys** :

- l'URL du projet (`https://xxxx.supabase.co`) ;
- la **clé publique** (« Publishable key », `sb_publishable_…`).

Ne copiez **jamais** la clé secrète (« Secret key » ou `service_role`) dans
l'application ni dans le code.

Copiez `config/dev.example.json` en `config/dev.json` et remplissez :

```json
{
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_KEY": "sb_publishable_…",
  "PRIVACY_URL": "https://votre-site.fr/confidentialite",
  "SUPPORT_EMAIL": "contact@votre-site.fr"
}
```

Ce fichier n'est pas versionné (voir `.gitignore`).

## 6. Désigner les administrateurs du contenu

Pour qu'une personne puisse modifier les questions depuis l'application ou l'API,
ajoutez son identifiant (visible dans **Authentication → Users**) :

```sql
insert into public.admins (user_id) values ('UUID-DE-L-UTILISATEUR');
```

Les membres de l'équipe peuvent aussi modifier la table `questions` directement
dans le **Table Editor** du tableau de bord.

## 7. Comptes de démonstration pour Apple et Google

Les équipes de validation des stores doivent pouvoir se connecter, mais ne peuvent
pas recevoir de code par e-mail. Créez un compte dédié :

**Authentication → Users → Add user → Create new user**, avec une adresse du type
`revue-stores@votre-domaine.fr`, un mot de passe solide, et « Auto Confirm User »
coché. Dans l'application, l'écran de connexion propose « Compte de démonstration :
mot de passe ». Donnez ces identifiants dans les formulaires de publication.

## 8. Vérifier

1. Lancez l'application avec `--dart-define-from-file=config/dev.json`.
2. Connectez-vous avec votre e-mail, créez le profil, faites un quiz.
3. Dans **Table Editor**, vérifiez que `answers` et `sessions` se remplissent.
4. Dans le profil de l'application, « Tout est synchronisé » doit s'afficher.
5. Testez « Supprimer mon compte » avec un compte de test : l'utilisateur et toutes
   ses lignes disparaissent.

## Mettre à jour les Lois du Jeu (chaque été)

1. Modifiez ou désactivez les questions concernées (`active = false` les masque sans
   perdre l'historique des réponses).
2. Mettez à jour `laws_edition` (par ex. `2026/27`).
3. Les téléphones reçoivent le nouveau contenu à leur prochaine synchronisation.
