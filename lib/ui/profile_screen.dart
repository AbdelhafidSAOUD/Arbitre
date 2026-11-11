import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/user_data.dart';
import '../theme.dart';
import 'common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late String level, role, goal;
  late bool largeText;

  @override
  void initState() {
    super.initState();
    final p = AppScope.read(context).profile;
    _name = TextEditingController(text: p.firstName ?? '');
    level = p.level;
    role = p.role;
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
    await s.saveProfile(s.profile.copyWith(firstName: _name.text.trim(), level: level, role: role, goal: goal, largeText: largeText));
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
            const Text('Votre profil, vos réponses, vos révisions, vos séances, vos matchs et vos badges seront effacés. '
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
        const Headline(eyebrow: 'Profil', title: 'Mon profil d’arbitre'),
        const SizedBox(height: 16),
        TextField(controller: _name, maxLength: 30, decoration: const InputDecoration(labelText: 'Prénom (facultatif)')),
        const SizedBox(height: 6),
        _dropdown('Niveau', level, profileLevels, (v) => level = v),
        const SizedBox(height: 14),
        _dropdown('Fonction principale', role, profileRoles, (v) => role = v),
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
