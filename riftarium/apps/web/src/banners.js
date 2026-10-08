/* Illustrations officielles Riftbound (CDN Riot). Jamais hébergées en local. */
const NEWS = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live"

/* Sur petit écran, une largeur réduite suffit (écrans ≤ 768 px, DPR ≤ 3) :
   l'image d'arrière-plan arrive plus vite et le LCP mobile s'améliore. */
const SMALL_SCREEN = typeof window !== "undefined" && window.innerWidth <= 768

export function bannerUrl(hash, width = 1600) {
  return `${NEWS}/${hash}?auto=format&w=${SMALL_SCREEN ? Math.min(width, 1080) : width}`
}

/* Seules clés lues : le splash d'accueil (SPLASH_KEYS dans home/homeData.js) et l'image de partage (seo.js). */
export const BANNERS = {
  /* Cinématique de lancement — accueil et image de partage par défaut. */
  home: bannerUrl("9e26afe304d2c40664b119a9da0ef82cff692f54-3840x2160.png", 1920),
  /* Champion (Riven) — parcourir les cartes. */
  cards: bannerUrl("4e9fa6cb967a660994b07ac4a42edafa134324f9-4500x2531.jpg"),
  /* Équipage (Gangplank) — construire un deck. */
  decks: bannerUrl("c84b72546ca00618ae705f2a7b9239a75111408c-5219x2936.jpg"),
  /* Table de jeu — decks partagés. */
  community: bannerUrl("91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg")
}
