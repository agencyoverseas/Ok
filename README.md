# Locks by Afro — repo fusionné

**App = design + fonctionnalités de la version B** (compte client, fidélité, notif, avis masquables, responsive, logo header, login→accueil, diagnostic intégré court/long)
**Shell = ton repo A** : clés centralisées dans `config.js` + PWA (installable + offline) + structure Vercel.

## Fichiers
| Fichier | Rôle |
|---|---|
| `index.html` | App cliente (réservation, espace client, fidélité, diagnostic intégré) |
| `admin.html` | **Admin sécurisé** — PIN serveur via edge function `admin` |
| `config.js` | Clés Supabase + contact (déjà remplies, projet `gnbpaytmhigbbnijovlg`) |
| `sw.js` | Service worker PWA (cache `lba-v7`) |
| `manifest.json` / `manifest-admin.json` | PWA cliente / admin |
| `icon-192/512`, `apple-touch-icon`, `favicon-32`, `logo.png` | Icônes + logo |
| `schema.sql` | Schéma DB (doc, non servi par Vercel) |

## Déploiement Vercel
Static, aucune config. Racine = ce dossier. App = `/`, admin = `/admin.html`.
Push sur `agencyoverseas/Locksafro` → Vercel redéploie.

## config.js
Clés Supabase + coordonnées déjà renseignées. Si tu vides `SUPABASE_URL`/`SUPABASE_ANON_KEY` → **mode démo** (rien enregistré). La clé ANON en clair est **normale** (clé publique).

## Admin
PIN **serveur** (edge function `admin`), plus de code client-side.
1ère ouverture de `admin.html` → définir le PIN (4-8 chiffres). Token stocké local (`lba_admin`).

## Acompte
30 % par défaut, **éditable par prestation** côté admin (table `services`, colonnes `deposit_type`/`deposit_value`).

## Changements vs ton ancien repo A
- Diagnostic **intégré** au parcours → `diagnostic.html` supprimé.
- `admin.html` = **nouvel admin sécurisé** (remplace l'ancien à mot de passe + lecture tables directe ; les refs cassées `.from('media')`/`.from('diagnostics_clients')` n'existent plus).
- `logo-mark.png` retiré (inutilisé), `supabase/0` retiré (déchet).
- Données via edge functions (`site-data`, `slots`, `account`, `admin`) → l'app ne lit plus les tables en direct.

## À vérifier
- RLS : 6 tables ont le RLS désactivé côté base (`content_calendar`, `post_logs`, `hashtag_clusters`, `drive_media`, `agent_instructions`, `system_config`). L'app n'y touche pas, mais elles restent exposées via l'API REST anon. À durcir quand tu veux.
