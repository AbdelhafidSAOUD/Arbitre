import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content.dart';
import 'local_store.dart';

/// Questions et fiches. Ordre de priorité :
/// 1. la dernière version reçue du serveur (gardée en cache) ;
/// 2. sinon, le contenu livré avec l'application (assets/content).
/// Ainsi, l'application fonctionne dès le premier lancement, même hors ligne,
/// et le contenu se met à jour sans republier l'application.
class ContentRepository {
  ContentRepository(this._store, {AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final LocalStore _store;
  final AssetBundle _bundle;

  List<Question> questions = [];
  Map<int, Lesson> lessons = {};

  Future<void> load() async {
    final cached = _store.loadContentCache();
    if (cached != null && cached.questions.isNotEmpty) {
      _set(cached.questions, cached.lessons);
      return;
    }
    final q = jsonDecode(await _bundle.loadString('assets/content/questions.json')) as List;
    final l = jsonDecode(await _bundle.loadString('assets/content/lessons.json')) as List;
    _set(
      [for (final row in q) Question.fromJson(Map<String, dynamic>.from(row as Map))],
      [for (final row in l) Lesson.fromJson(Map<String, dynamic>.from(row as Map))],
    );
  }

  Future<void> replace(List<Question> qs, List<Lesson> ls) async {
    // Un serveur vide (contenu pas encore importé) ne doit pas effacer
    // le contenu embarqué.
    if (qs.isEmpty) return;
    _set(qs, ls.isEmpty ? lessons.values.toList() : ls);
    await _store.saveContentCache(questions, lessons.values.toList());
  }

  void _set(List<Question> qs, List<Lesson> ls) {
    questions = qs.where((q) => q.isValid).toList();
    lessons = {for (final l in ls) l.law: l};
  }

  int countForLaw(int law) => questions.where((q) => q.law == law).length;

  Question? byId(String id) {
    for (final q in questions) {
      if (q.id == id) return q;
    }
    return null;
  }
}
