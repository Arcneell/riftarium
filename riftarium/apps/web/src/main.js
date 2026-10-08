/* Feuilles globales d'abord : elles doivent précéder les styles scoped des composants dans le bundle. */
import "./styles/fonts.css"
import "./styles/tokens.css"
import "./styles/base.css"
import "./styles/layout.css"
import { createApp } from "vue"
import App from "./App.vue"
import Icon from "./components/Icon.vue"
import { router } from "./router.js"

const app = createApp(App)
app.component("Icon", Icon)

/* PWA : service worker (public/sw.js) pour consulter les règles hors ligne.
   Prod uniquement — en dev, Vite sert les modules à la volée et un SW ne
   ferait que mettre en cache des artefacts éphémères. Échec silencieux :
   sans SW le site fonctionne normalement, simplement sans mode hors ligne. */
if (import.meta.env.PROD && "serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/sw.js").catch(() => {})
  })
}

app.use(router).mount("#app")
