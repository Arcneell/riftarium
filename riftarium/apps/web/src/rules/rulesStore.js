/* Règles officielles (`/data/rules-fr.json`, embarqué dans l'image web) : un seul
   téléchargement pour toute la session, partagé par le lecteur intégral
   (`/regles/officielles`) et les sujets de l'aide avancée, qui n'en citent que
   quelques sections. Le fichier pèse plusieurs centaines de kilo-octets : le
   relire à chaque navigation coûtait un aller-retour et un `JSON.parse` complet. */
const RULES_URL = "/data/rules-fr.json"

let cache = null
let pending = null

/**
 * Renvoie l'objet des documents de règles (`{core, tournament, …}`).
 * Rejette si le fichier est indisponible ou illisible : à l'appelant d'afficher
 * un état « texte officiel indisponible » plutôt qu'une page vide.
 */
export function loadRulesDocuments() {
  if (cache) return Promise.resolve(cache)
  /* Deux écrans qui demandent les règles en même temps partagent la même requête. */
  if (!pending) {
    pending = fetch(RULES_URL)
      .then((response) => {
        /* `fetch` ne rejette pas sur 404 ou 500 : sans ce contrôle, `json()`
           avalait la page d'erreur de nginx et l'index se construisait à vide. */
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        return response.json()
      })
      .then((documents) => {
        cache = documents
        return documents
      })
      .finally(() => {
        /* Échec : la requête suivante réessaiera. Succès : le cache prend le relais. */
        pending = null
      })
  }
  return pending
}

/** Vide le cache — réservé aux tests, pour repartir d'un état neuf. */
export function resetRulesCache() {
  cache = null
  pending = null
}
