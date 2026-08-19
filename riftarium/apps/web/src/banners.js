/* Illustrations officielles Riftbound (CDN Riot). Jamais hébergées en local. */
const NEWS = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live"

/* Sur petit écran, une largeur réduite suffit (écrans ≤ 768 px, DPR ≤ 3) :
   l'image d'arrière-plan arrive plus vite et le LCP mobile s'améliore. */
const SMALL_SCREEN = typeof window !== "undefined" && window.innerWidth <= 768

export function bannerUrl(hash, width = 1600) {
  return `${NEWS}/${hash}?auto=format&w=${SMALL_SCREEN ? Math.min(width, 1080) : width}`
}

export const BANNERS = {
  /* Cinématique de lancement — accueil et porte d'entrée du compte. */
  home: bannerUrl("9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png", 1920),
  auth: bannerUrl("9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png", 1920),
  /* Champion (Riven) — parcourir les cartes. */
  cards: bannerUrl("4e9fa6cb967a660994b07ac4a42edafa134324f9-4500x2531.jpg"),
  /* Équipage (Gangplank) — construire un deck. */
  decks: bannerUrl("c84b72546ca00618ae705f2a7b9239a75111408c-5219x2936.jpg"),
  /* Inventaire / produits — collection personnelle. */
  collection: bannerUrl("2282ecab240f601b611ae89b5ade895e1b6b2de4-4676x2630.jpg"),
  /* Table de jeu — decks partagés. */
  community: bannerUrl("91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg"),
  table: bannerUrl("91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg", 1800),
  /* Maître Poro — apprendre et consulter les règles. */
  rules: bannerUrl("bf44d943577f839588eddde2483fc582c068841c-4800x2700.jpg")
}
