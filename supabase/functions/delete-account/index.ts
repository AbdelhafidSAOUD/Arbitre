// Suppression définitive du compte de l'utilisateur connecté.
// Exigée par l'App Store et Google Play, et par le RGPD (droit à l'effacement).
//
// L'utilisateur est identifié par son jeton de connexion (JWT) : il ne peut
// supprimer que son propre compte. Toutes ses données (profil, réponses,
// révisions, séances, matchs, badges) sont effacées en cascade.
//
// Déploiement : supabase functions deploy delete-account
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Méthode non autorisée" }, 405);

  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return json({ error: "Non connecté" }, 401);

  // La clé de service est fournie automatiquement par Supabase aux
  // fonctions. Elle ne quitte jamais le serveur.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );

  // 1. Identifier l'utilisateur à partir de son propre jeton.
  const { data: { user }, error: userError } = await admin.auth.getUser(token);
  if (userError || !user) return json({ error: "Session invalide" }, 401);

  // 2. Supprimer le compte : les données suivent en cascade.
  const { error } = await admin.auth.admin.deleteUser(user.id);
  if (error) {
    console.error("delete-account", user.id, error.message);
    return json({ error: "La suppression a échoué. Réessayez plus tard." }, 500);
  }
  return json({ deleted: true });
});
