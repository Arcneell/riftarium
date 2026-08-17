import { createApp } from "vue";
import App from "./App.vue";
import { router } from "./router.js";
import "./assets/main.css";

const app = createApp(App);

const finePointer = window.matchMedia("(pointer: fine)").matches;
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

/* v-tilt : inclinaison 3D + reflet qui suit le curseur (desktop uniquement) */
app.directive("tilt", {
  mounted(el) {
    if (!finePointer || reducedMotion) return;
    el.classList.add("tilt");
    el.addEventListener("mousemove", event => {
      const rect = el.getBoundingClientRect();
      const x = (event.clientX - rect.left) / rect.width;
      const y = (event.clientY - rect.top) / rect.height;
      el.style.setProperty("--rx", `${(0.5 - y) * 12}deg`);
      el.style.setProperty("--ry", `${(x - 0.5) * 12}deg`);
      el.style.setProperty("--gx", `${x * 100}%`);
      el.style.setProperty("--gy", `${y * 100}%`);
    });
    el.addEventListener("mouseleave", () => {
      el.style.setProperty("--rx", "0deg");
      el.style.setProperty("--ry", "0deg");
    });
  }
});

/* v-reveal : apparition en douceur à l'entrée dans le viewport */
const revealObserver = new IntersectionObserver(entries => {
  for (const entry of entries) {
    if (entry.isIntersecting) {
      entry.target.classList.add("visible");
      revealObserver.unobserve(entry.target);
    }
  }
}, { threshold: 0.12 });

app.directive("reveal", {
  mounted(el, binding) {
    if (reducedMotion) return;
    el.classList.add("reveal");
    if (binding.value) el.style.transitionDelay = `${binding.value * 90}ms`;
    revealObserver.observe(el);
  }
});

app.use(router).mount("#app");
