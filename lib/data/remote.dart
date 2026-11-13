import 'package:supabase_flutter/supabase_flutter.dart';

import '../logic/categories.dart';
import '../logic/srs.dart';
import '../models/content.dart';
import '../models/user_data.dart';
import 'sync.dart';

/// Erreur définitive (donnée refusée par le serveur) : l'écriture est
/// abandonnée pour ne pas bloquer la file. À l'inverse, une erreur réseau
/// laisse l'écriture dans la file pour un nouvel essai.
class PermanentSyncError implements Exception {
  PermanentSyncError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Accès au serveur Supabase. La clé utilisée est la clé publique
/// (« publishable ») : la sécurité repose sur les règles RLS de la base, pas sur
/// le secret de la clé.
class Remote {
  Remote(this.client);
  final SupabaseClient client;

  String? get userId => client.auth.currentUser?.id;
  String? get email => client.auth.currentUser?.email;

  Stream<String?> get userChanges => client.auth.onAuthStateChange.map((s) => s.session?.user.id);

  // ---------------------------------------------------------------- Comptes

  Future<void> sendCode(String email) => client.auth.signInWithOtp(email: email, shouldCreateUser: true);

  Future<void> verifyCode(String email, String code) =>
      client.auth.verifyOTP(type: OtpType.email, email: email, token: code);

  /// Connexion par mot de passe, réservée aux comptes créés depuis le tableau
  /// de bord (comptes de démonstration pour les équipes de validation
  /// d'Apple et de Google, qui ne peuvent pas recevoir de code par e-mail).
  Future<void> signInWithPassword(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => client.auth.signOut();

  Future<void> deleteAccount() async {
    final res = await client.functions.invoke('delete-account', method: HttpMethod.post);
    if (res.status != 200) {
      throw Exception('Suppression refusée (${res.status})');
    }
  }

  // ---------------------------------------------------------------- Contenu

  Future<({List<Question> questions, List<Lesson> lessons, List<CategorySuggestion> suggestions})>
      fetchContent() async {
    final q = await client.from('questions').select().eq('active', true);
    final l = await client.from('lessons').select();
    final c = await client.from('category_suggestions').select().eq('status', 'validee');
    return (
      questions: [for (final row in q) Question.fromJson(row)].where((x) => x.isValid).toList(),
      lessons: [for (final row in l) Lesson.fromJson(row)],
      suggestions: [for (final row in c) CategorySuggestion.fromRow(row)],
    );
  }

  // ------------------------------------------------------- Données personnelles

  /// Récupère toutes les données de l'utilisateur. Renvoie null si son
  /// profil n'existe pas encore sur le serveur (nouveau compte).
  Future<UserData?> fetchUserData(String uid) async {
    final profileRow = await client.from('profiles').select().eq('id', uid).maybeSingle();
    if (profileRow == null) return null;

    final results = await Future.wait([
      client.from('law_stats').select('law,total,correct'),
      client.from('offside_stats').select('total,correct'),
      client.from('reviews').select('question_id,box,due'),
      client.from('sessions').select().order('created_at', ascending: false).limit(UserData.maxSessions),
      client.from('matches').select().order('played_on', ascending: false),
      client.from('badges').select('badge_id'),
      client.from('physical_results').select().order('done_on', ascending: false),
      client.from('category_suggestions').select().eq('user_id', uid),
    ]);
    final offsideRows = results[1];
    final data = UserData(
      profile: Profile.fromRow(profileRow),
      laws: {
        for (final r in results[0]) (r['law'] as num).toInt(): Tally((r['total'] as num).toInt(), (r['correct'] as num).toInt()),
      },
      offside: offsideRows.isEmpty
          ? const Tally()
          : Tally((offsideRows.first['total'] as num).toInt(), (offsideRows.first['correct'] as num).toInt()),
      reviews: {
        for (final r in results[2])
          r['question_id'] as String: ReviewEntry(box: (r['box'] as num).toInt(), due: r['due'] as String),
      },
      sessions: [for (final r in results[3].reversed) SessionRecord.fromRow(r)],
      matches: [for (final r in results[4]) MatchEntry.fromRow(r)],
      badges: {for (final r in results[5]) r['badge_id'] as String},
      physical: [for (final r in results[6]) PhysicalResult.fromRow(r)],
      suggestions: [for (final r in results[7]) CategorySuggestion.fromRow(r)],
    );
    return data;
  }

  /// Envoie un lot d'écritures (voir [batchOps]).
  Future<void> applyBatch(List<SyncOp> batch) async {
    final first = batch.first;
    try {
      if (first.action == 'delete') {
        for (final op in batch) {
          await client.from(op.table).delete().match({
            for (final e in op.data.entries)
              if (e.value != null) e.key: e.value as Object,
          });
        }
      } else {
        await client
            .from(first.table)
            .upsert(dedupeRows(batch), onConflict: first.onConflict, ignoreDuplicates: first.ignoreDuplicates);
      }
    } on PostgrestException catch (e) {
      // 22xxx : donnée invalide ; 23xxx : contrainte non respectée ;
      // 42xxx : accès refusé ou requête invalide. Inutile de réessayer.
      final code = e.code ?? '';
      if (code.startsWith('22') || code.startsWith('23') || code.startsWith('42')) {
        throw PermanentSyncError('${first.table} : ${e.message}');
      }
      rethrow;
    }
  }
}
