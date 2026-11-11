/// Une écriture en attente d'envoi au serveur.
///
/// Toutes les modifications sont d'abord appliquées sur l'appareil, puis
/// ajoutées à une file conservée localement. La file est envoyée dès que le
/// réseau est disponible : l'application fonctionne donc hors ligne, et
/// rien n'est perdu. Les identifiants sont générés sur l'appareil (UUID),
/// ce qui rend chaque envoi rejouable sans créer de doublon.
class SyncOp {
  const SyncOp.upsert(this.table, this.data, {this.onConflict = 'id', this.ignoreDuplicates = false})
      : action = 'upsert';
  const SyncOp.delete(this.table, this.data)
      : action = 'delete',
        onConflict = 'id',
        ignoreDuplicates = false;
  const SyncOp._(this.table, this.action, this.data, this.onConflict, this.ignoreDuplicates);

  final String table;
  final String action; // upsert | delete
  final Map<String, dynamic> data;
  final String onConflict;
  final bool ignoreDuplicates;

  List<String> get keyColumns => onConflict.split(',').map((s) => s.trim()).toList();
  String get rowKey => keyColumns.map((c) => '${data[c]}').join('|');

  bool sameBatchAs(SyncOp o) =>
      action == 'upsert' &&
      o.action == 'upsert' &&
      table == o.table &&
      onConflict == o.onConflict &&
      ignoreDuplicates == o.ignoreDuplicates;

  Map<String, dynamic> toJson() => {
        't': table,
        'a': action,
        'd': data,
        'c': onConflict,
        'i': ignoreDuplicates,
      };

  factory SyncOp.fromJson(Map<String, dynamic> j) => SyncOp._(
        j['t'] as String,
        j['a'] as String,
        Map<String, dynamic>.from(j['d'] as Map),
        (j['c'] as String?) ?? 'id',
        (j['i'] as bool?) ?? false,
      );
}

/// Regroupe les écritures consécutives de même nature pour les envoyer en
/// une seule requête. L'ordre global est conservé. Dans un lot, une même
/// ligne n'apparaît qu'une fois (la dernière version gagne), car PostgreSQL
/// refuse de modifier deux fois la même ligne dans un seul upsert.
List<List<SyncOp>> batchOps(List<SyncOp> ops) {
  final batches = <List<SyncOp>>[];
  for (final op in ops) {
    if (batches.isNotEmpty && batches.last.first.sameBatchAs(op)) {
      batches.last.add(op);
    } else {
      batches.add([op]);
    }
  }
  return batches;
}

/// Lignes à envoyer pour un lot d'upserts, dédoublonnées.
List<Map<String, dynamic>> dedupeRows(List<SyncOp> batch) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final op in batch) {
    byKey.remove(op.rowKey);
    byKey[op.rowKey] = op.data;
  }
  return byKey.values.toList();
}
