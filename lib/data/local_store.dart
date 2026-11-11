import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content.dart';
import '../models/user_data.dart';
import 'sync.dart';

/// Stockage sur l'appareil. Chaque utilisateur a ses propres clés, et ses
/// données sont effacées à la déconnexion. Une donnée illisible
/// (corrompue) est ignorée plutôt que de bloquer l'application.
class LocalStore {
  LocalStore(this._prefs);
  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  String _userKey(String uid) => 'user_data_v1_$uid';
  String _queueKey(String uid) => 'sync_queue_v1_$uid';
  static const _contentKey = 'content_cache_v1';

  UserData? loadUserData(String uid) {
    final raw = _prefs.getString(_userKey(uid));
    if (raw == null) return null;
    try {
      return UserData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Données locales illisibles, ignorées : $e');
      return null;
    }
  }

  Future<void> saveUserData(String uid, UserData data) =>
      _prefs.setString(_userKey(uid), jsonEncode(data.toJson()));

  List<SyncOp> loadQueue(String uid) {
    final raw = _prefs.getString(_queueKey(uid));
    if (raw == null) return [];
    try {
      return [for (final o in jsonDecode(raw) as List) SyncOp.fromJson(Map<String, dynamic>.from(o as Map))];
    } catch (e) {
      debugPrint('File de synchronisation illisible, ignorée : $e');
      return [];
    }
  }

  Future<void> saveQueue(String uid, List<SyncOp> queue) =>
      _prefs.setString(_queueKey(uid), jsonEncode([for (final o in queue) o.toJson()]));

  Future<void> deleteUser(String uid) async {
    await _prefs.remove(_userKey(uid));
    await _prefs.remove(_queueKey(uid));
  }

  ({List<Question> questions, List<Lesson> lessons})? loadContentCache() {
    final raw = _prefs.getString(_contentKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        questions: [for (final q in j['questions'] as List) Question.fromJson(Map<String, dynamic>.from(q as Map))],
        lessons: [for (final l in j['lessons'] as List) Lesson.fromJson(Map<String, dynamic>.from(l as Map))],
      );
    } catch (e) {
      debugPrint('Cache de contenu illisible, ignoré : $e');
      return null;
    }
  }

  Future<void> saveContentCache(List<Question> questions, List<Lesson> lessons) => _prefs.setString(
        _contentKey,
        jsonEncode({
          'questions': [for (final q in questions) q.toJson()],
          'lessons': [for (final l in lessons) l.toJson()],
        }),
      );
}
