# Publier sur Google Play et l'App Store

## Avant tout

- [ ] Choisir l'**identifiant définitif** de l'application. Il ne pourra plus changer
      après la première publication. Exemple : `fr.votreorganisation.sifflet`.
      - Android : `applicationId` et `namespace` dans `android/app/build.gradle.kts`.
      - iOS : « Bundle Identifier » dans Xcode (`ios/Runner.xcodeproj`).
- [ ] Remplacer l'icône (par exemple avec le paquet `flutter_launcher_icons`).
- [ ] Mettre en ligne la **politique de confidentialité** (modèle :
      `docs/POLITIQUE_DE_CONFIDENTIALITE.md`) et indiquer son adresse dans `PRIVACY_URL`.
- [ ] Configurer le serveur (`docs/MISE_EN_SERVICE.md`), y compris l'envoi d'e-mails
      SMTP et le compte de démonstration.
- [ ] Faire relire les questions par un formateur.
- [ ] Augmenter `version:` dans `pubspec.yaml` à chaque nouvelle publication
      (`1.0.0+1`, puis `1.0.1+2`… le nombre après `+` doit toujours augmenter).

## Google Play

### 1. Compte développeur

- [play.google.com/console](https://play.google.com/console), 25 $ une seule fois.
- **Compte d'organisation** (association, ligue, société) recommandé : l'application
  paraît sous ce nom et le test fermé obligatoire ne s'applique pas. Il faut un
  numéro D-U-N-S (gratuit, quelques jours d'attente).
- **Compte personnel** : avant la mise en production, test fermé avec au moins
  **12 testeurs pendant 14 jours consécutifs**.

### 2. Clé de signature

À faire une seule fois. Conservez la clé et ses mots de passe en lieu sûr (deux
copies) : sans eux, plus aucune mise à jour n'est possible.

```bash
keytool -genkey -v -keystore ~/sifflet-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Créez `android/key.properties` (jamais versionné) :

```properties
storePassword=VOTRE_MOT_DE_PASSE
keyPassword=VOTRE_MOT_DE_PASSE
keyAlias=upload
storeFile=/chemin/vers/sifflet-upload.jks
```

Activez **Play App Signing** dans la console (proposé par défaut) : Google conserve
la clé de signature finale, la vôtre ne sert qu'à envoyer les versions.

### 3. Compiler

```bash
flutter build appbundle --release --dart-define-from-file=config/prod.json
```

Le fichier à envoyer est `build/app/outputs/bundle/release/app-release.aab`.

### 4. Fiche et déclarations dans la console

- **Accès à l'application** : donnez les identifiants du compte de démonstration.
- **Public cible** : si vous incluez les moins de 13 ans, le programme « Familles »
  de Google s'applique (règles supplémentaires). Viser **13 ans et plus** simplifie
  la publication ; l'application gère de toute façon l'accord parental jusqu'à 15 ans.
- **Sécurité des données** : voir le tableau en bas de page.
- **Suppression des données** : indiquez que la suppression se fait dans
  l'application (Profil → Supprimer mon compte) et donnez l'adresse de contact.
- **Classification du contenu** : questionnaire IARC (application éducative, pas de
  violence ni d'achat).

### 5. Tests puis production

Test interne → test fermé → production. La première validation prend de quelques
heures à quelques jours.

## App Store (iPhone)

### 1. Compte développeur

- [developer.apple.com/programs](https://developer.apple.com/programs), 99 $ par an.
- Compte d'organisation recommandé (numéro D-U-N-S requis).

### 2. Compiler

Il faut un Mac avec Xcode, ou un service de compilation en ligne
(Codemagic, Bitrise, GitHub Actions avec un exécuteur macOS).

1. Ouvrez `ios/Runner.xcworkspace` dans Xcode.
2. **Signing & Capabilities** : choisissez votre équipe et le Bundle Identifier.
3. Compilez :

```bash
flutter build ipa --release --dart-define-from-file=config/prod.json
```

4. Envoyez `build/ios/ipa/*.ipa` avec l'application **Transporter** (ou depuis Xcode).

### 3. App Store Connect

- Créez l'application, renseignez la fiche, les captures d'écran (iPhone 6,7 pouces au
  minimum) et l'adresse de la politique de confidentialité.
- **Confidentialité de l'app** : voir le tableau ci-dessous.
- **Informations pour la vérification** : identifiants du compte de démonstration.
- **TestFlight** pour faire tester avant publication.
- Classification par âge : 4+ (aucun contenu sensible).

Règles Apple déjà respectées par l'application :

- suppression du compte depuis l'application (règle 5.1.1(v)) ;
- pas de connexion Google ou Facebook, donc « Se connecter avec Apple » n'est pas
  exigé (si vous en ajoutez une, il faudra ajouter Apple aussi) ;
- chiffrement standard uniquement (`ITSAppUsesNonExemptEncryption = false`).

## Déclarations « données collectées »

À recopier dans Google Play (Sécurité des données) et App Store Connect
(Confidentialité de l'app).

| Donnée | Collectée | Usage | Liée à l'identité | Partagée |
|---|---|---|---|---|
| Adresse e-mail | Oui | Gestion du compte | Oui | Non |
| Prénom (facultatif) | Oui | Personnalisation | Oui | Non |
| Année de naissance | Oui | Accord parental, conformité | Oui | Non |
| E-mail d'un parent (moins de 15 ans) | Oui | Accord parental | Oui | Non |
| Réponses aux quiz, progression | Oui | Fonctionnement de l'application | Oui | Non |
| Matchs, notes, auto-évaluation | Oui | Fonctionnement de l'application | Oui | Non |
| Localisation, contacts, photos | Non | — | — | — |
| Publicité, suivi entre applications | Non | — | — | — |

- Données chiffrées en transit : **oui** (HTTPS).
- Suppression possible à la demande : **oui**, dans l'application.
- Suivi (« tracking ») au sens d'Apple : **non**.

Si vous ajoutez plus tard un outil de statistiques ou de rapport de plantage
(Sentry, Firebase Crashlytics…), mettez ces déclarations à jour.
