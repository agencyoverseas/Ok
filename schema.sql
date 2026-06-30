-- =====================================================================
-- LOCKS BY AFRO — Schéma Supabase
-- À exécuter dans Supabase → SQL Editor → New query → Run.
-- Sécurité : le public NE peut PAS écrire directement clients/bookings.
-- La réservation passe par l'Edge Function "create-sumup-checkout"
-- (clé service_role = bypass RLS). L'admin connecté a accès complet.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- TABLES ----------
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  phone text,
  email text unique,
  gender text,
  notes text,
  created_at timestamptz default now()
);

create table if not exists services (
  id text primary key,                 -- ex : 'creation', 'retwist'
  name text not null,
  category text,
  description text,
  price_cents int not null default 0,
  duree_txt text,                      -- affichage : '1h30', 'sur devis'
  duration_min int not null default 60,
  deposit_type text not null default 'percent',  -- 'percent' | 'fixed' | 'none'
  deposit_value int not null default 30,         -- % si percent, centimes si fixed
  active boolean not null default true,
  sort_order int not null default 0,
  image_url text
);

create table if not exists service_questions (   -- questions adaptables (optionnel)
  id uuid primary key default gen_random_uuid(),
  service_category text,
  label text not null,
  field_type text not null default 'text',  -- text|textarea|select|boolean|photo
  options jsonb,
  required boolean default false,
  sort_order int default 0
);

create table if not exists bookings (
  id uuid primary key default gen_random_uuid(),
  client_id uuid references clients(id) on delete set null,
  service_id text references services(id),
  start_at timestamptz not null,
  end_at timestamptz,
  status text not null default 'pending',   -- pending|confirmed|done|cancelled|no_show
  total_amount_cents int default 0,
  deposit_amount_cents int default 0,
  payment_status text not null default 'unpaid', -- unpaid|deposit_paid|paid
  sumup_checkout_id text,
  intake_responses jsonb,                   -- réponses du diagnostic
  created_at timestamptz default now()
);

create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid references bookings(id) on delete cascade,
  sumup_checkout_id text,
  amount_cents int not null default 0,
  currency text default 'EUR',
  status text default 'pending',            -- pending|paid|failed
  type text default 'deposit',              -- deposit|balance
  created_at timestamptz default now()
);

create table if not exists availability (
  id uuid primary key default gen_random_uuid(),
  weekday int not null,                     -- 0=dimanche … 6=samedi
  open_time time not null,
  close_time time not null,
  slot_minutes int default 60
);

create table if not exists closures (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  reason text
);

-- ---------- RLS ----------
alter table clients          enable row level security;
alter table services         enable row level security;
alter table service_questions enable row level security;
alter table bookings         enable row level security;
alter table payments         enable row level security;
alter table availability     enable row level security;
alter table closures         enable row level security;

-- Lecture publique des tables "vitrine"
create policy "public read services"   on services          for select using (active or auth.uid() is not null);
create policy "public read questions"  on service_questions for select using (true);
create policy "public read avail"      on availability      for select using (true);
create policy "public read closures"   on closures          for select using (true);

-- Admin (utilisateur connecté) = accès complet
create policy "admin all services"   on services          for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all questions"  on service_questions for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all avail"      on availability      for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all closures"   on closures          for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all clients"    on clients           for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all bookings"   on bookings          for all using (auth.uid() is not null) with check (auth.uid() is not null);
create policy "admin all payments"   on payments          for all using (auth.uid() is not null) with check (auth.uid() is not null);
-- NB : clients/bookings/payments n'ont AUCUNE policy pour 'anon' →
--      le public ne peut pas y accéder directement (sécurité).
--      L'Edge Function écrit via la clé service_role (bypass RLS).

-- ---------- SEED ----------
insert into services (id,name,category,description,price_cents,duree_txt,duration_min,deposit_type,deposit_value,sort_order) values
 ('creation',  'Démarrage de locs',          'Création',     'Création de vos locs sur cheveux naturels, méthode adaptée à votre texture.', 12000, '3h – 5h', 240, 'percent', 30, 1),
 ('retwist',   'Entretien / Retwist',        'Entretien',    'Resserrage des racines pour des locs nettes et saines.',                      4500,  '1h30',    90,  'percent', 30, 2),
 ('doublage',  'Doublage de locs',           'Densification','Densification : on double vos locs pour plus de volume.',                     8000,  'sur devis',120, 'percent', 30, 3),
 ('rattachage','Rattachage / Réparation',    'Réparation',   'Réparation des locs cassées ou fragilisées.',                                 3500,  'sur devis',90,  'percent', 30, 4),
 ('coloration','Coloration',                 'Couleur',      'Mise en couleur respectueuse de vos locs.',                                   7000,  '2h',      120, 'percent', 30, 5),
 ('consult',   'Consultation personnalisée', 'Conseil',      'Bilan complet + plan d''entretien sur-mesure.',                               2500,  '30 min',  30,  'none',    0,  6)
on conflict (id) do nothing;

insert into availability (weekday,open_time,close_time,slot_minutes) values
 (2,'09:00','18:00',60),(3,'09:00','18:00',60),(4,'09:00','18:00',60),(5,'09:00','18:00',60),(6,'09:00','17:00',60);

-- =====================================================================
-- QUESTIONNAIRE DE DIAGNOSTIC (éditable depuis l'admin)
-- =====================================================================
create table if not exists diagnostic_questions (
  id uuid primary key default gen_random_uuid(),
  section text,
  q_key text not null unique,                -- clé technique (jsonb)
  label text not null,
  field_type text not null default 'text',   -- text|tel|email|number|textarea|boolean|select|checkboxes
  options jsonb,                             -- pour select / checkboxes
  required boolean default false,
  conditional_on text,                       -- q_key déclencheur
  conditional_value text,                    -- valeur qui révèle la question
  sort_order int default 0
);
alter table diagnostic_questions enable row level security;
create policy "public read diagq" on diagnostic_questions for select using (true);
create policy "admin all diagq"   on diagnostic_questions for all using (auth.uid() is not null) with check (auth.uid() is not null);

insert into diagnostic_questions (section,q_key,label,field_type,options,required,conditional_on,conditional_value,sort_order) values
 ('Informations personnelles','prenom','Prénom','text',null,true,null,null,1),
 ('Informations personnelles','nom','Nom','text',null,true,null,null,2),
 ('Informations personnelles','tel','Téléphone','tel',null,true,null,null,3),
 ('Informations personnelles','email','E-mail','email',null,true,null,null,4),
 ('Vos locs','nb_locks','Combien de locks avez-vous ?','number',null,false,null,null,5),
 ('Vos locs','doublage','Avez-vous déjà fait un doublage ?','boolean',null,false,null,null,6),
 ('Vos locs','nb_doubler','Combien de locks souhaitez-vous doubler ?','number',null,false,'doublage','Oui',7),
 ('Vos locs','rattach','Avez-vous déjà fait rattacher vos locks ?','boolean',null,false,null,null,8),
 ('Vos locs','rattach_detail','Par qui et quand ?','text',null,false,'rattach','Oui',9),
 ('Vos locs','cassure','Avez-vous des cassures ou des locks fragiles ?','boolean',null,false,null,null,10),
 ('Vos locs','nb_concernees','Combien de locks sont concernées ?','number',null,false,'cassure','Oui',11),
 ('Routine & soins','routine','Votre routine capillaire actuelle','textarea',null,false,null,null,12),
 ('Routine & soins','abo','Avez-vous un abonnement chez Locks by Afro ?','boolean',null,false,null,null,13),
 ('Routine & soins','scalp','Problèmes spécifiques du cuir chevelu ?','checkboxes','["Psoriasis","Alopécie","Pellicules","Sécheresse","Démangeaisons","Autre"]'::jsonb,false,null,null,14),
 ('Routine & soins','scalp_autre_txt','Précisez','text',null,false,'scalp','Autre',15),
 ('Routine & soins','autre_pro','Déjà coiffé(e) par un autre professionnel récemment ?','boolean',null,false,null,null,16),
 ('Routine & soins','autre_pro_detail','Quelle prestation et quand ?','text',null,false,'autre_pro','Oui',17),
 ('Mode de vie','sport','Pratiquez-vous du sport régulièrement ?','boolean',null,false,null,null,18),
 ('Mode de vie','sport_freq','À quelle fréquence ?','text',null,false,'sport','Oui',19),
 ('Mode de vie','objectif','Objectif de votre visite / remarques','textarea',null,false,null,null,20)
on conflict (q_key) do nothing;

-- =====================================================================
-- CONTENU DU SITE (éditable depuis l'admin) + GALERIE + STOCKAGE IMAGES
-- =====================================================================

-- Réglages texte/coordonnées/logo (clé -> valeur)
create table if not exists site_settings (
  key text primary key,
  value text
);
alter table site_settings enable row level security;
drop policy if exists "public read settings" on site_settings;
drop policy if exists "admin all settings"   on site_settings;
create policy "public read settings" on site_settings for select using (true);
create policy "admin all settings"   on site_settings for all using (auth.uid() is not null) with check (auth.uid() is not null);

insert into site_settings (key,value) values
 ('site_name','Locks by Afro'),
 ('hero_title',''),
 ('hero_subtitle','Atelier spécialisé en locs. Avant chaque prestation, on analyse vos cheveux et votre cuir chevelu pour travailler juste, sain et durable.'),
 ('about_text','Un espace dédié aux locs, où chaque tête est prise au sérieux. On prend le temps de comprendre vos cheveux avant d''y toucher.'),
 ('phone',''),('address','À renseigner — Guadeloupe'),('whatsapp',''),('email','contact@locksbyafro.fr'),('logo_url',''),
 ('open_days','2,3,4,5,6'),('hours','09:00,10:00,11:00,13:00,14:00,15:00,16:00'),
 ('hero_kicker','Création · Entretien · Doublage · Rattachage'),
 ('sec_presta_kicker','Prestations'),('sec_presta_title','Ce qu''on travaille'),
 ('sec_rituel_kicker','La méthode'),('sec_rituel_title','Trois temps, un résultat'),
 ('sec_gal_kicker','Galerie'),('sec_gal_title','Réalisations'),
 ('rituel_1_title','Diagnostic'),('rituel_1_text','Un questionnaire complet sur vos locs, votre routine et votre cuir chevelu. C''est la base de tout.'),
 ('rituel_2_title','Prestation sur-mesure'),('rituel_2_text','On choisit ensemble la prestation adaptée à l''état réel de vos cheveux, jamais à l''aveugle.'),
 ('rituel_3_title','Routine & suivi'),('rituel_3_text','Vous repartez avec un plan d''entretien clair pour garder des locs nettes et solides.'),
 ('avis_text','Les avis de vos clients s''afficheront ici. Connectez votre fiche Google pour les remonter automatiquement après chaque rendez-vous.'),
 ('avis_btn','Laisser un avis Google'),('avis_url','')
on conflict (key) do nothing;

-- Galerie (photos avant/après)
create table if not exists gallery (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  caption text,
  sort_order int default 0,
  created_at timestamptz default now()
);
alter table gallery enable row level security;
drop policy if exists "public read gallery" on gallery;
drop policy if exists "admin all gallery"   on gallery;
create policy "public read gallery" on gallery for select using (true);
create policy "admin all gallery"   on gallery for all using (auth.uid() is not null) with check (auth.uid() is not null);

-- Stockage des images (logo, galerie, photos prestations) — bucket public
insert into storage.buckets (id, name, public) values ('media','media', true) on conflict (id) do nothing;
drop policy if exists "media public read"  on storage.objects;
drop policy if exists "media admin insert" on storage.objects;
drop policy if exists "media admin update" on storage.objects;
drop policy if exists "media admin delete" on storage.objects;
create policy "media public read"  on storage.objects for select using (bucket_id='media');
create policy "media admin insert" on storage.objects for insert to authenticated with check (bucket_id='media');
create policy "media admin update" on storage.objects for update to authenticated using (bucket_id='media');
create policy "media admin delete" on storage.objects for delete to authenticated using (bucket_id='media');

-- ============================================================
-- Créneaux occupés d'un jour donné (pour barrer les horaires pris sur le site public).
-- N'expose QUE les heures occupées (HH:MM), jamais les données client.
-- d = date au format 'YYYY-MM-DD'.
-- ============================================================
create or replace function busy_slots(d text)
returns setof text
language sql
security definer
set search_path = public
as $$
  select to_char(start_at at time zone 'UTC','HH24:MI')
  from bookings
  where status in ('pending','confirmed')
    and to_char(start_at at time zone 'UTC','YYYY-MM-DD') = d;
$$;
grant execute on function busy_slots(text) to anon, authenticated;
