-- =====================================================================
-- Sifflet Académie : schéma initial
-- Toutes les tables de données personnelles sont protégées par
-- Row Level Security (RLS) : chaque utilisateur ne voit que ses données.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Administrateurs du contenu (questions, fiches)
-- ---------------------------------------------------------------------
create table public.admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admins enable row level security;
-- Aucune policy : la table n'est lisible et modifiable que via le
-- tableau de bord Supabase (rôle service) ou la fonction ci-dessous.

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.admins a where a.user_id = auth.uid());
$$;

-- ---------------------------------------------------------------------
-- Profils
-- ---------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text check (first_name is null or char_length(first_name) <= 30),
  level text not null default 'district'
    check (level in ('jeune', 'district', 'federal', 'formateur')),
  role text not null default 'central'
    check (role in ('central', 'assistant', 'mixte')),
  goal text not null default 'progresser'
    check (goal in ('progresser', 'examen', 'reprise', 'former')),
  birth_year int check (birth_year between 1920 and 2100),
  parental_consent boolean not null default false,
  parent_email text check (parent_email is null or char_length(parent_email) <= 254),
  privacy_accepted_at timestamptz,
  privacy_version text,
  large_text boolean not null default false,
  xp int not null default 0 check (xp >= 0),
  streak int not null default 0 check (streak >= 0),
  last_active date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy "profil : lecture de son propre profil"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);
create policy "profil : création de son propre profil"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);
create policy "profil : modification de son propre profil"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
-- Pas de policy delete : la suppression passe par la suppression du
-- compte (fonction delete-account), qui efface tout en cascade.

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Contenu pédagogique (lisible par tout utilisateur connecté)
-- ---------------------------------------------------------------------
create table public.questions (
  id text primary key,
  law int not null check (law between 1 and 17),
  kind text not null check (kind in ('connaissance', 'situation')),
  difficulty int not null default 1 check (difficulty between 1 and 3),
  role_tag text check (role_tag is null or role_tag in ('assistant')),
  question text not null,
  options jsonb not null check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 4),
  answer_index int not null check (answer_index >= 0 and answer_index < 4),
  explanation text not null,
  laws_edition text not null default '2025/26',
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.questions enable row level security;

create policy "questions : lecture des questions actives"
  on public.questions for select to authenticated
  using (active or (select public.is_admin()));
create policy "questions : gestion par les administrateurs"
  on public.questions for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create trigger questions_updated_at
  before update on public.questions
  for each row execute function public.touch_updated_at();

create table public.lessons (
  law int primary key check (law between 1 and 17),
  title text not null,
  points jsonb not null check (jsonb_typeof(points) = 'array'),
  updated_at timestamptz not null default now()
);
alter table public.lessons enable row level security;

create policy "fiches : lecture"
  on public.lessons for select to authenticated
  using (true);
create policy "fiches : gestion par les administrateurs"
  on public.lessons for all to authenticated
  using ((select public.is_admin()))
  with check ((select public.is_admin()));

create trigger lessons_updated_at
  before update on public.lessons
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Réponses (journal, en ajout seulement)
-- ---------------------------------------------------------------------
create table public.answers (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  question_id text,               -- null pour le simulateur de hors-jeu
  law int not null check (law between 1 and 17),
  correct boolean not null,
  mode text not null check (char_length(mode) <= 60),
  answered_at timestamptz not null default now()
);
create index answers_user_law_idx on public.answers (user_id, law);
alter table public.answers enable row level security;

create policy "réponses : lecture des siennes"
  on public.answers for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "réponses : ajout des siennes"
  on public.answers for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- Statistiques par loi, calculées à partir des réponses.
-- security_invoker : la vue applique la RLS de la table answers.
create view public.law_stats
with (security_invoker = true) as
  select user_id,
         law,
         count(*)::int as total,
         (count(*) filter (where correct))::int as correct
  from public.answers
  group by user_id, law;

create view public.offside_stats
with (security_invoker = true) as
  select user_id,
         count(*)::int as total,
         (count(*) filter (where correct))::int as correct
  from public.answers
  where question_id is null and law = 11
  group by user_id;

-- ---------------------------------------------------------------------
-- Révisions espacées
-- ---------------------------------------------------------------------
create table public.reviews (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  question_id text not null,
  box int not null check (box between 1 and 5),
  due date not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, question_id)
);
alter table public.reviews enable row level security;

create policy "révisions : accès aux siennes"
  on public.reviews for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- Séances (quiz, examens)
-- ---------------------------------------------------------------------
create table public.sessions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mode text not null check (char_length(mode) <= 60),
  correct int not null check (correct >= 0),
  total int not null check (total > 0 and correct <= total),
  is_exam boolean not null default false,
  passed boolean,
  played_on date not null,
  created_at timestamptz not null default now()
);
create index sessions_user_idx on public.sessions (user_id, played_on desc);
alter table public.sessions enable row level security;

create policy "séances : lecture des siennes"
  on public.sessions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "séances : ajout des siennes"
  on public.sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- Carnet de matchs et auto-évaluation
-- ---------------------------------------------------------------------
create table public.matches (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  played_on date not null,
  competition text not null check (char_length(competition) between 1 and 80),
  role text not null check (role in ('Arbitre central', 'Arbitre assistant', 'Quatrième arbitre')),
  observer_note numeric(4, 2) check (observer_note is null or observer_note between 0 and 20),
  improvement text check (improvement is null or char_length(improvement) <= 500),
  eval_placement smallint not null default 3 check (eval_placement between 1 and 5),
  eval_physical smallint not null default 3 check (eval_physical between 1 and 5),
  eval_laws smallint not null default 3 check (eval_laws between 1 and 5),
  eval_management smallint not null default 3 check (eval_management between 1 and 5),
  eval_communication smallint not null default 3 check (eval_communication between 1 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index matches_user_idx on public.matches (user_id, played_on desc);
alter table public.matches enable row level security;

create policy "matchs : accès aux siens"
  on public.matches for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create trigger matches_updated_at
  before update on public.matches
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- Badges
-- ---------------------------------------------------------------------
create table public.badges (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  badge_id text not null check (char_length(badge_id) <= 40),
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);
alter table public.badges enable row level security;

create policy "badges : lecture des siens"
  on public.badges for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "badges : ajout des siens"
  on public.badges for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------
-- Droits : les utilisateurs anonymes n'ont accès à rien.
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke execute on function public.is_admin() from anon;
