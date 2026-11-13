-- Tests de sécurité : chaque utilisateur ne voit et ne modifie que ses données.
-- Lancés par tool/test_database.sh. Toute erreur arrête le script.
\set ON_ERROR_STOP on

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.fr'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.fr');

-- Petite aide : vérifie qu'une instruction est refusée.
create or replace function pg_temp.doit_echouer(stmt text, motif text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    raise notice 'OK (refusé comme prévu) : % [%]', motif, sqlerrm;
    return;
  end;
  raise exception 'ÉCHEC DE SÉCURITÉ : % a été accepté', motif;
end $$;
grant execute on function pg_temp.doit_echouer(text, text) to anon, authenticated;

------------------------------------------------------------ Utilisateur A
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';

insert into public.profiles (id, birth_year, privacy_accepted_at, privacy_version)
  values ('00000000-0000-0000-0000-00000000000a', 1995, now(), '2026-11');
insert into public.answers (id, question_id, law, correct, mode) values
  (gen_random_uuid(), 'L11-x', 11, true, 'Quiz rapide'),
  (gen_random_uuid(), 'L11-y', 11, false, 'Quiz rapide'),
  (gen_random_uuid(), null, 11, true, 'Simulateur hors-jeu');
insert into public.reviews (question_id, box, due) values ('L11-y', 1, current_date + 1);
insert into public.sessions (id, mode, correct, total, played_on) values (gen_random_uuid(), 'Quiz rapide', 2, 3, current_date);
insert into public.matches (id, played_on, competition, role, observer_note) values
  (gen_random_uuid(), current_date, 'U17 Régional 1', 'Arbitre central', 14.5);
insert into public.badges (badge_id) values ('first');
update public.profiles set level = 'ligue', level_detail = 'R2', role = 'assistant', also_other = true
  where id = '00000000-0000-0000-0000-00000000000a';
insert into public.matches (id, played_on, competition, role, status, goal) values
  (gen_random_uuid(), current_date + 3, 'Régional 2', 'Arbitre assistant', 'prevu', 'Rester à hauteur');
insert into public.physical_results (id, test, value, passed, done_on) values (gen_random_uuid(), 'sprint30', '4,88', true, current_date);
insert into public.category_suggestions (id, country, kind, label) values
  ('00000000-0000-0000-0000-0000000000c1', 'MA', 'categorie', 'Arbitre Botola Pro');

select pg_temp.doit_echouer(
  $$insert into public.profiles (id) values ('00000000-0000-0000-0000-00000000000b')$$,
  'A crée le profil de B');
select pg_temp.doit_echouer(
  $$insert into public.answers (id, user_id, law, correct, mode) values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000b', 1, true, 'x')$$,
  'A écrit une réponse au nom de B');
select pg_temp.doit_echouer(
  $$insert into public.questions (id, law, kind, question, options, answer_index, explanation) values ('pirate', 1, 'connaissance', 'q', '["a","b"]', 0, 'e')$$,
  'A (non administrateur) ajoute une question');
select pg_temp.doit_echouer(
  $$insert into public.matches (id, played_on, competition, role, observer_note) values (gen_random_uuid(), current_date, 'X', 'Arbitre central', 25)$$,
  'note d’observateur hors de 0–20');
select pg_temp.doit_echouer(
  $$update public.profiles set level = 'inventee' where id = '00000000-0000-0000-0000-00000000000a'$$,
  'catégorie inconnue sur le profil');
select pg_temp.doit_echouer(
  $$insert into public.matches (id, played_on, competition, role, satisfaction) values (gen_random_uuid(), current_date, 'X', 'Arbitre central', 9)$$,
  'satisfaction hors de 1–5');
select pg_temp.doit_echouer(
  $$insert into public.category_suggestions (id, country, kind, label, status) values (gen_random_uuid(), 'FR', 'categorie', 'Auto-validée', 'validee')$$,
  'A valide lui-même sa proposition de catégorie');
select pg_temp.doit_echouer(
  $$insert into public.category_suggestions (id, user_id, country, kind, label) values (gen_random_uuid(), '00000000-0000-0000-0000-00000000000b', 'FR', 'categorie', 'Au nom de B')$$,
  'A propose une catégorie au nom de B');
select pg_temp.doit_echouer(
  $$insert into public.physical_results (id, test, value, done_on) values (gen_random_uuid(), 'marathon', '3h', current_date)$$,
  'test physique inconnu');
-- Pas de règle de modification pour l'auteur : la validation ne touche aucune ligne.
update public.category_suggestions set status = 'validee';
-- Pas de règle de modification : la mise à jour ne touche aucune ligne.
update public.answers set correct = true;
delete from public.answers;

do $$ begin
  if (select count(*) from public.questions) < 50 then raise exception 'questions non lisibles'; end if;
  if (select count(*) from public.answers where correct) <> 2 then raise exception 'historique de réponses modifié ou supprimé'; end if;
  if (select total from public.law_stats where law = 11) <> 3 then raise exception 'law_stats incorrect'; end if;
  if (select correct from public.offside_stats) <> 1 then raise exception 'offside_stats incorrect'; end if;
  raise notice 'OK : A lit le contenu et ses statistiques, son historique est inaltérable';
end $$;

------------------------------------------------------------ Utilisateur B
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  if exists (select 1 from public.profiles) then raise exception 'B voit le profil de A'; end if;
  if exists (select 1 from public.answers) then raise exception 'B voit les réponses de A'; end if;
  if exists (select 1 from public.law_stats) then raise exception 'B voit les statistiques de A'; end if;
  if exists (select 1 from public.reviews) then raise exception 'B voit les révisions de A'; end if;
  if exists (select 1 from public.sessions) then raise exception 'B voit les séances de A'; end if;
  if exists (select 1 from public.matches) then raise exception 'B voit les matchs de A'; end if;
  if exists (select 1 from public.badges) then raise exception 'B voit les badges de A'; end if;
  if exists (select 1 from public.physical_results) then raise exception 'B voit les tests physiques de A'; end if;
  if exists (select 1 from public.category_suggestions) then raise exception 'B voit une proposition non validée de A'; end if;
  raise notice 'OK : B ne voit aucune donnée de A';
end $$;
update public.profiles set xp = 99999 where id = '00000000-0000-0000-0000-00000000000a';
delete from public.matches;
delete from public.physical_results;
reset role;
do $$ begin
  if (select status from public.category_suggestions) <> 'en_attente' then raise exception 'A a validé sa propre proposition'; end if;
  if (select count(*) from public.physical_results) <> 1 then raise exception 'B a supprimé les tests physiques de A'; end if;
end $$;
-- Un administrateur valide la proposition : elle devient visible de tous.
update public.category_suggestions set status = 'validee';
set role authenticated;
set request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin
  if (select count(*) from public.category_suggestions where status = 'validee') <> 1 then
    raise exception 'B ne voit pas la catégorie validée';
  end if;
  raise notice 'OK : une catégorie validée est visible des autres arbitres';
end $$;
update public.category_suggestions set label = 'Modifiée par B';
delete from public.category_suggestions;
reset role;
do $$ begin
  if (select xp from public.profiles where id = '00000000-0000-0000-0000-00000000000a') <> 0 then raise exception 'B a modifié le profil de A'; end if;
  if (select count(*) from public.matches) <> 2 then raise exception 'B a supprimé les matchs de A'; end if;
  if (select label from public.category_suggestions) <> 'Arbitre Botola Pro' then raise exception 'B a modifié une catégorie'; end if;
  raise notice 'OK : B ne peut ni modifier ni supprimer les données de A';
end $$;

------------------------------------------------------------ Visiteur anonyme
set role anon;
-- psql affiche les NOTICE ; on masque les lignes vides de résultat.
select pg_temp.doit_echouer($$select * from public.questions$$, 'un visiteur non connecté lit les questions');
select pg_temp.doit_echouer($$select * from public.profiles$$, 'un visiteur non connecté lit les profils');
reset role;

------------------------------------------------------------ Suppression du compte
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
do $$ begin
  if exists (select 1 from public.profiles where id = '00000000-0000-0000-0000-00000000000a')
     or exists (select 1 from public.answers) or exists (select 1 from public.matches)
     or exists (select 1 from public.reviews) or exists (select 1 from public.sessions)
     or exists (select 1 from public.badges) or exists (select 1 from public.physical_results) then
    raise exception 'données restantes après suppression du compte';
  end if;
  if exists (select 1 from public.category_suggestions where user_id is not null) then
    raise exception 'la proposition de catégorie reste liée au compte supprimé';
  end if;
  raise notice 'OK : la suppression du compte efface toutes ses données';
end $$;

\echo 'Tous les tests de sécurité sont passés.'
