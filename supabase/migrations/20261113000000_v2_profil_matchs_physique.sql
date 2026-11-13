-- =====================================================================
-- Sifflet Académie v2 :
--  - profil : pays, catégorie officielle détaillée, niveau précis,
--    catégorie personnalisée, double fonction ;
--  - catégories et niveaux proposés par les arbitres (validés par un
--    administrateur avant d'être visibles par tous) ;
--  - carnet de matchs : matchs prévus, débriefing complet ;
--  - résultats des tests physiques.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Profils
-- ---------------------------------------------------------------------
alter table public.profiles drop constraint if exists profiles_level_check;
update public.profiles set level = 'jad' where level = 'jeune';
alter table public.profiles
  add column country text not null default 'FR' check (country in ('FR', 'MA')),
  add column level_detail text check (level_detail is null or char_length(level_detail) <= 60),
  add column custom_category text check (custom_category is null or char_length(custom_category) <= 60),
  add column also_other boolean not null default false,
  add constraint profiles_level_check check (level in (
    'jad', 'jal', 'jaf', 'district', 'ligue', 'regional', 'federal', 'formateur', 'observateur',
    'ma_jeune', 'ma_ligue', 'ma_national', 'autre'));

-- ---------------------------------------------------------------------
-- Catégories et niveaux proposés par les arbitres
-- ---------------------------------------------------------------------
create table public.category_suggestions (
  id uuid primary key,
  -- Un libellé de catégorie n'est pas une donnée personnelle : il reste
  -- disponible pour les autres arbitres si son auteur supprime son compte.
  user_id uuid default auth.uid() references auth.users (id) on delete set null,
  country text not null check (country in ('FR', 'MA')),
  kind text not null check (kind in ('categorie', 'niveau')),
  category_id text check (category_id is null or char_length(category_id) <= 70),
  label text not null check (char_length(label) between 1 and 60),
  status text not null default 'en_attente' check (status in ('en_attente', 'validee', 'refusee')),
  created_at timestamptz not null default now(),
  check (kind = 'categorie' or category_id is not null)
);
create index category_suggestions_status_idx on public.category_suggestions (status, country);
alter table public.category_suggestions enable row level security;

create policy "catégories : lecture des validées et des siennes"
  on public.category_suggestions for select to authenticated
  using (status = 'validee' or (select auth.uid()) = user_id or (select public.is_admin()));
create policy "catégories : proposition en attente"
  on public.category_suggestions for insert to authenticated
  with check ((select auth.uid()) = user_id and status = 'en_attente');
-- Pas de modification par l'auteur : seul un administrateur valide ou refuse.
create policy "catégories : validation par les administrateurs"
  on public.category_suggestions for update to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));
create policy "catégories : suppression par les administrateurs"
  on public.category_suggestions for delete to authenticated
  using ((select public.is_admin()));

-- ---------------------------------------------------------------------
-- Carnet de matchs : matchs prévus et débriefing
-- ---------------------------------------------------------------------
alter table public.matches
  add column status text not null default 'joue' check (status in ('prevu', 'joue')),
  add column teams text check (teams is null or char_length(teams) <= 80),
  add column goal text check (goal is null or char_length(goal) <= 200),
  add column goal_result text check (goal_result is null or goal_result in ('atteint', 'en_partie', 'non_atteint')),
  add column satisfaction smallint check (satisfaction is null or satisfaction between 1 and 5),
  add column feeling text check (feeling is null or char_length(feeling) <= 1000),
  add column work_points jsonb not null default '[]'::jsonb
    check (jsonb_typeof(work_points) = 'array' and jsonb_array_length(work_points) <= 20),
  add column next_goal text check (next_goal is null or char_length(next_goal) <= 200),
  add column yellow_cards smallint not null default 0 check (yellow_cards between 0 and 30),
  add column red_cards smallint not null default 0 check (red_cards between 0 and 11),
  add column eval_concentration smallint not null default 3 check (eval_concentration between 1 and 5);

-- ---------------------------------------------------------------------
-- Tests physiques
-- ---------------------------------------------------------------------
create table public.physical_results (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  test text not null check (test in ('sprint40', 'sds', 'sprint30', 'coda', 'ariet')),
  value text not null check (char_length(value) between 1 and 20),
  passed boolean,
  done_on date not null,
  created_at timestamptz not null default now()
);
create index physical_results_user_idx on public.physical_results (user_id, done_on desc);
alter table public.physical_results enable row level security;

create policy "tests physiques : accès aux siens"
  on public.physical_results for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

revoke all on public.category_suggestions, public.physical_results from anon;
