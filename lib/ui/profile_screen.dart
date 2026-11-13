import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'category_picker.dart';
import 'common.dart';
import 'progress_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late RefereeIdentity identity;
  late String goal;
  late bool largeText;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    _name = TextEditingController(text: p.firstName ?? '');
    identity = RefereeIdentity(
      country: p.country,
      level: p.level,
      levelDetail: p.levelDetail,
      customCategory: p.customCategory,
      role: p.role == 'mixte' ? 'central' : p.role,
      alsoOther: p.alsoOther || p.role == 'mixte',
    );
    goal = p.goal;
    largeText = p.largeText;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    await s.saveProfile(s.profile.copyWith(
      firstName: _name.text.trim(),
      country: identity.country,
      level: identity.level,
      levelDetail: () => identity.levelDetail,
      customCategory: () => identity.customCategory,
      role: identity.role,
      alsoOther: identity.alsoOther,
      goal: goal,
      largeText: largeText,
    ));
    if (mounted) showMessage(context, 'Profil enregistré : programme du jour mis à jour');
  }

  Future<void> _signOut() async {
    final s = AppScope.read(context);
    final nav = Navigator.of(context);
    var ok = await s.signOut();
    if (!ok && mounted) {
      final force = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Données non envoyées'),
          content: Text('${s.pendingChanges} modification(s) n’ont pas encore pu être envoyées au serveur. '
              'Si vous vous déconnectez maintenant, elles seront perdues.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Rester connecté')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Se déconnecter')),
          ],
        ),
      );
      if (force == true) ok = await s.signOut(force: true);
    }
    if (ok) nav.popUntil((r) => r.isFirst);
  }

  Future<void> _deleteAccount() async {
    final s = AppScope.read(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Supprimer définitivement mon compte ?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Votre profil, vos réponses, vos révisions, vos séances, vos matchs, vos tests physiques et vos badges seront effacés. '
                'Cette action est irréversible.'),
            const SizedBox(height: 12),
            TextField(
              controller: confirm,
              onChanged: (_) => setD(() {}),
              decoration: const InputDecoration(labelText: 'Tapez SUPPRIMER pour confirmer'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: confirm.text.trim().toUpperCase() == 'SUPPRIMER' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );
    confirm.dispose();
    if (ok != true) return;
    try {
      await s.deleteAccount();
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(const SnackBar(content: Text('Compte et données supprimés')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('La suppression a échoué. Vérifiez votre connexion et réessayez.')));
    }
  }

  void _export() {
    final text = AppScope.read(context).exportData();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mes données'),
        content: SizedBox(
          width: 420,
          height: 360,
          child: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) showMessage(context, 'Données copiées dans le presse-papiers');
            },
            child: const Text('Copier'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.sc;
    final lastSync = s.lastSyncAt;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: PageList(children: [
        _IdentityCard(s: s),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgressScreen())),
          icon: const Icon(Icons.insights),
          label: const Text('Ma progression détaillée'),
        ),
        const SectionTitle('Modifier mon profil'),
        TextField(controller: _name, maxLength: 30, decoration: const InputDecoration(labelText: 'Prénom (facultatif)')),
        const SizedBox(height: 6),
        RefereeIdentityForm(value: identity, onChanged: (v) => setState(() => identity = v)),
        const SizedBox(height: 14),
        _dropdown('Objectif', goal, profileGoals, (v) => goal = v),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: largeText,
          onChanged: (v) => setState(() => largeText = v),
          title: const Text('Texte agrandi'),
        ),
        const SizedBox(height: 6),
        FilledButton(onPressed: _save, child: const Text('Enregistrer le profil')),

        const SectionTitle('Compte et synchronisation'),
        ListBox(children: [
          if (s.isLocalMode)
            const Row2(
              title: 'Mode local',
              subtitle: 'Aucun serveur configuré : vos données restent uniquement sur cet appareil.',
            )
          else ...[
            Row2(title: s.email ?? 'Compte connecté', subtitle: 'Connexion par code e-mail'),
            Row2(
              title: s.syncing
                  ? 'Synchronisation en cours…'
                  : s.pendingChanges > 0
                      ? '${s.pendingChanges} modification(s) en attente d’envoi'
                      : 'Tout est synchronisé',
              subtitle: s.syncError ??
                  (lastSync == null
                      ? 'Vos données sont sauvegardées sur le serveur dès que le réseau est disponible.'
                      : 'Dernière synchronisation à ${lastSync.hour}h${lastSync.minute.toString().padLeft(2, '0')}'),
              trailing: const Icon(Icons.sync),
              onTap: s.syncing ? null : () => s.sync(pull: true),
            ),
          ],
        ]),

        const SectionTitle('Mes données'),
        ListBox(children: [
          Row2(
            title: 'Voir et copier mes données',
            subtitle: 'Toutes les informations enregistrées à votre sujet',
            trailing: const Icon(Icons.chevron_right),
            onTap: _export,
          ),
          Row2(
            title: 'Politique de confidentialité',
            subtitle: 'Acceptée le ${_date(s.profile.privacyAcceptedAt)} (version ${s.profile.privacyVersion ?? '—'})',
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl), mode: LaunchMode.externalApplication),
          ),
          Row2(
            title: 'Nous contacter',
            subtitle: AppConfig.supportEmail,
            trailing: const Icon(Icons.copy),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: AppConfig.supportEmail));
              if (context.mounted) showMessage(context, 'Adresse copiée');
            },
          ),
        ]),
        const SizedBox(height: 22),
        if (!s.isLocalMode) ...[
          OutlinedButton(onPressed: _signOut, child: const Text('Se déconnecter')),
          const SizedBox(height: 10),
        ],
        TextButton(
          style: TextButton.styleFrom(foregroundColor: c.red),
          onPressed: _deleteAccount,
          child: Text(s.isLocalMode ? 'Effacer toutes mes données' : 'Supprimer mon compte'),
        ),
      ]),
    );
  }

  String _date(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    return d == null ? '—' : '${d.day}/${d.month}/${d.year}';
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

/// Carte d'identité de l'arbitre : catégorie officielle, fonction, palier.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.s});
  final AppState s;

  @override
  Widget build(BuildContext context) {
    final c = context.sc;
    final p = s.profile;
    final lv = s.level;
    final tag = BoxDecoration(color: c.onNavy.withValues(alpha: .14), borderRadius: BorderRadius.circular(99));
    Widget pill(String t) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: tag,
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.onNavy)),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.navy, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CATÉGORIE OFFICIELLE (DÉCLARÉE)',
            style: TextStyle(fontSize: 11.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: c.onNavy.withValues(alpha: .75))),
        const SizedBox(height: 4),
        Text(p.categoryLabel,
            style: TextStyle(fontFamily: kDisplay, fontSize: 26, fontWeight: FontWeight.w800, color: c.onNavy, height: 1.1)),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(99)),
            child: Text(p.isAssistant ? 'Arbitre assistant' : 'Arbitre central',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.onCard)),
          ),
          if (p.alsoOther) pill(p.isAssistant ? 'Aussi central' : 'Aussi assistant'),
          pill(p.country == 'MA' ? 'Maroc' : 'France'),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text('${lv.name} d’entraînement · ${p.xp} XP',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.onNavy)),
          ),
          if (lv.next != null)
            Text('${lv.next! - p.xp} XP avant ${lv.nextName}', style: TextStyle(fontSize: 12, color: c.onNavy.withValues(alpha: .75))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: lv.progress(p.xp),
            minHeight: 7,
            backgroundColor: c.onNavy.withValues(alpha: .18),
            color: c.card,
          ),
        ),
        const SizedBox(height: 6),
        Text('Le palier mesure votre travail dans l’application. Il ne change jamais votre catégorie officielle.',
            style: TextStyle(fontSize: 12, color: c.onNavy.withValues(alpha: .75))),
      ]),
    );
  }
}
