import { createApp } from "vue"
import App from "./App.vue"
import Icon from "./components/Icon.vue"
import { router } from "./router.js"
import "./assets/main.css"

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

const finePointer = window.matchMedia("(pointer: fine)").matches
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches

/* v-tilt : inclinaison 3D + reflet qui suit le curseur (desktop uniquement) */
app.directive("tilt", {
  mounted(el) {
    if (!finePointer || reducedMotion) return
    el.classList.add("tilt")
    let frame = null
    const onMove = (event) => {
      if (frame) return
      frame = requestAnimationFrame(() => {
        frame = null
        const rect = el.getBoundingClientRect()
        const x = (event.clientX - rect.left) / rect.width
        const y = (event.clientY - rect.top) / rect.height
        el.style.setProperty("--rx", `${(0.5 - y) * 12}deg`)
        el.style.setProperty("--ry", `${(x - 0.5) * 12}deg`)
        el.style.setProperty("--gx", `${x * 100}%`)
        el.style.setProperty("--gy", `${y * 100}%`)
      })
    }
    const onLeave = () => {
      el.style.setProperty("--rx", "0deg")
      el.style.setProperty("--ry", "0deg")
    }
    el.addEventListener("mousemove", onMove)
    el.addEventListener("mouseleave", onLeave)
    el._tiltCleanup = () => {
      cancelAnimationFrame(frame)
      el.removeEventListener("mousemove", onMove)
      el.removeEventListener("mouseleave", onLeave)
    }
  },
  unmounted(el) {
    el._tiltCleanup?.()
  }
})

/* v-reveal : apparition à l'entrée dans le viewport (fiable après navigation SPA) */
const revealObserver = new IntersectionObserver(
  (entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        entry.target.classList.add("visible")
        revealObserver.unobserve(entry.target)
      }
    }
  },
  /* Précharge large sous le viewport : en scroll rapide, l'élément est déjà révélé
     quand il devient visible. */
  { threshold: 0, rootMargin: "0px 0px 45% 0px" }
)

function inViewport(el) {
  const rect = el.getBoundingClientRect()
  return rect.bottom > 0 && rect.top < (window.innerHeight || 800)
}

app.directive("reveal", {
  mounted(el, binding) {
    if (reducedMotion) {
      el.classList.add("reveal", "visible")
      return
    }
    el.classList.add("reveal")
    if (typeof binding.value === "number") {
      el.style.transitionDelay = `${Math.min(binding.value * 60, 180)}ms`
    }
    /* deux frames : laisse passer la transition de page sans délai perceptible */
    el._revealTimer = requestAnimationFrame(() => {
      el._revealTimer = requestAnimationFrame(() => {
        if (inViewport(el)) el.classList.add("visible")
        else revealObserver.observe(el)
      })
    })
  },
  unmounted(el) {
    cancelAnimationFrame(el._revealTimer)
    revealObserver.unobserve(el)
  }
})

app.use(router).mount("#app")
