import { createApp } from "vue";
import App from "./App.vue";
import Icon from "./components/Icon.vue";
import { router } from "./router.js";
import "./assets/main.css";

const app = createApp(App);
app.component("Icon", Icon);

const finePointer = window.matchMedia("(pointer: fine)").matches;
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* v-tilt : inclinaison 3D + reflet qui suit le curseur (desktop uniquement) */
app.directive("tilt", {
  mounted(el) {
    if (!finePointer || reducedMotion) return;
    el.classList.add("tilt");
    const onMove = event => {
      const rect = el.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width;
      const y = (event.clientY - rect.top) / rect.height;
      el.style.setProperty("--rx", `${(0.5 - y) * 12}deg`);
      el.style.setProperty("--ry", `${(x - 0.5) * 12}deg`);
      el.style.setProperty("--gx", `${x * 100}%`);
      el.style.setProperty("--gy", `${y * 100}%`);
    };
    const onLeave = () => {
      el.style.setProperty("--rx", "0deg");
      el.style.setProperty("--ry", "0deg");
    };
    el.addEventListener("mousemove", onMove);
    el.addEventListener("mouseleave", onLeave);
    el._tiltCleanup = () => {
      el.removeEventListener("mousemove", onMove);
      el.removeEventListener("mouseleave", onLeave);
    };
  },
  unmounted(el) {
    el._tiltCleanup?.();
  }
});

/* v-reveal : apparition à l'entrée dans le viewport (fiable après navigation SPA) */
const revealObserver = new IntersectionObserver(entries => {
  for (const entry of entries) {
    if (entry.isIntersecting) {
      entry.target.classList.add("visible");
      revealObserver.unobserve(entry.target);
    }
  }
}, { threshold: 0.06, rootMargin: "40px 0px" });

function inViewport(el) {
  const rect = el.getBoundingClientRect();
  return rect.bottom > 0 && rect.top < (window.innerHeight || 800);
}

app.directive("reveal", {
  mounted(el, binding) {
    if (reducedMotion) {
      el.classList.add("reveal", "visible");
      return;
    }
    el.classList.add("reveal");
    if (typeof binding.value === "number") {
      el.style.transitionDelay = `${binding.value * 90}ms`;
    }
    const kick = () => {
      if (inViewport(el)) el.classList.add("visible");
      else revealObserver.observe(el);
    };
    /* laisse passer la transition de page (transform du parent) */
    el._revealTimer = setTimeout(kick, 80);
  },
  unmounted(el) {
    clearTimeout(el._revealTimer);
    revealObserver.unobserve(el);
  }
});

app.use(router).mount("#app");
