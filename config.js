/* =======================================================================
   CONFIGURATION — LOCKS BY AFRO
   Remplis ces valeurs APRÈS avoir créé ton projet Supabase + ton compte SumUp.
   Tant que SUPABASE_URL / SUPABASE_ANON_KEY sont vides → le site tourne en
   MODE DÉMO (rien n'est enregistré, paiement simulé).
   ======================================================================= */
window.LBA_CONFIG = {
  /* Supabase — Project Settings → API */
  SUPABASE_URL: "https://gnbpaytmhigbbnijovlg.supabase.co",
  SUPABASE_ANON_KEY: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImduYnBheXRtaGlnYmJuaWpvdmxnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3MDM0MjEsImV4cCI6MjA5NzI3OTQyMX0.kmBbASuLU5ak9LQksZ8nBffty46J58VuyQgqs4iMGKo",

  /* Coordonnées affichées sur le site */
  WHATSAPP: "590000000000",  // numéro WhatsApp, format international SANS le +
  TEL:      "",              // ex : 0590 00 00 00
  EMAIL:    "contact@locksbyafro.fr",
  ADRESSE:  "À renseigner — Guadeloupe"

  /* Les clés SumUp (API key + merchant code) ne vont PAS ici :
     elles se mettent dans les Secrets des Edge Functions Supabase.
     Voir README + supabase/functions/. */
};
