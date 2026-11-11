import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'brand.dart';
import 'common.dart';

/// Création du profil. Recueille aussi :
/// - l'acceptation de la politique de confidentialité (version datée) ;
/// - l'accord d'un parent pour les moins de 15 ans (RGPD, art. 8).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _parentEmail;
  late String level, role, goal;
  int? birthYear;
  bool parentalConsent = false;
  bool privacy = false;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    _name = TextEditingController(text: p.firstName ?? '');
    _parentEmail = TextEditingController(text: p.parentEmail ?? '');
    level = p.level;
    role = p.role;
    goal = p.goal;
    birthYear = p.birthYear;
    parentalConsent = p.parentalConsent;
  }

  @override
  void dispose() {
    _name.dispose();
    _parentEmail.dispose();
    super.dispose();
  }

  bool get minor => Profile.isMinorBirthYear(birthYear);

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!privacy) {
      showMessage(context, 'Acceptez la politique de confidentialité pour continuer.');
      return;
    }
    if (minor && !parentalConsent) {
      showMessage(context, 'L’accord d’un parent ou tuteur est nécessaire avant 15 ans.');
      return;
    }
    setState(() => busy = true);
    final s = AppScope.read(context);
    await s.acceptPrivacyAndSave(s.profile.copyWith(
      firstName: _name.text.trim(),
      level: level,
      role: role,
      goal: goal,
      birthYear: birthYear,
      parentalConsent: minor && parentalConsent,
      parentEmail: minor ? _parentEmail.text.trim() : '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final now = DateTime.now().year;
    final previouslyAccepted = AppScope.of(context).profile.privacyAcceptedAt != null;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  const BrandMark(),
                  const SizedBox(height: 24),
                  Headline(
                    eyebrow: previouslyAccepted ? 'Mise à jour' : 'Bienvenue',
                    title: 'Votre profil d’arbitre',
                    subtitle: previouslyAccepted
                        ? 'Notre politique de confidentialité a changé. Relisez-la et confirmez vos informations.'
                        : 'Vos réponses adaptent les questions, la difficulté et votre programme du jour.',
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    maxLength: 30,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.givenName],
                    decoration: const InputDecoration(labelText: 'Prénom (facultatif)'),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: birthYear,
                    decoration: const InputDecoration(labelText: 'Année de naissance'),
                    items: [for (var y = now - 8; y >= now - 90; y--) DropdownMenuItem(value: y, child: Text('$y'))],
                    onChanged: (v) => setState(() => birthYear = v),
                    validator: (v) => v == null ? 'Indiquez votre année de naissance.' : null,
                  ),
                  const SizedBox(height: 14),
                  _dropdown('Niveau', level, profileLevels, (v) => level = v),
                  const SizedBox(height: 14),
                  _dropdown('Fonction principale', role, profileRoles, (v) => role = v),
                  const SizedBox(height: 14),
                  _dropdown('Objectif', goal, profileGoals, (v) => goal = v),
                  if (minor) ...[
                    const SizedBox(height: 20),
                    Panel(
                      color: c.cardSoft,
                      borderColor: c.card,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Accord parental', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        Text(
                          'Avant ${AppConfig.digitalConsentAge} ans, un parent ou tuteur doit autoriser '
                          'l’utilisation de vos données.',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _parentEmail,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-mail du parent ou tuteur'),
                          validator: (v) => minor && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '')
                              ? 'Indiquez l’e-mail d’un parent ou tuteur.'
                              : null,
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: parentalConsent,
                          onChanged: (v) => setState(() => parentalConsent = v ?? false),
                          title: const Text('Mon parent ou tuteur a lu la politique de confidentialité et donne son accord.'),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: privacy,
                    onChanged: (v) => setState(() => privacy = v ?? false),
                    title: Text.rich(TextSpan(children: [
                      const TextSpan(text: 'J’ai lu et j’accepte la '),
                      TextSpan(
                        text: 'politique de confidentialité',
                        style: TextStyle(color: c.pitch, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication),
                      ),
                      const TextSpan(text: '.'),
                    ])),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Text(previouslyAccepted ? 'Confirmer' : 'Commencer'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nous ne collectons que ce qui sert à votre progression. Vous pouvez exporter ou supprimer '
                    'vos données à tout moment depuis votre profil.',
                    style: TextStyle(fontSize: 13, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown(String label, String value, Map<String, String> options, void Function(String) set) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => setState(() => set(v ?? value)),
      );
}
