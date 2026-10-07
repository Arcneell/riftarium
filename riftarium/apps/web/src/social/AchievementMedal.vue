<script setup>
import { computed } from "vue"
import { achievementIconPaths } from "../achievementIcons.js"

/* Médaille hexagonale Forgée d'un haut fait : la forme reprend la gemme hex des
   impressions alternatives Riftbound, le palier donne la couleur du filet
   (bronze, argent, or, puis prisme irisé). L'icône est un tracé unique par haut
   fait (achievementIcons.js). Une médaille verrouillée est atténuée ; l'état et
   le palier sont dits au lecteur d'écran par l'aria-label (le sens ne repose
   pas sur la couleur). */
const props = defineProps({
  achievementKey: { type: String, default: "" },
  icon: { type: String, default: "" },
  tier: { type: String, default: "bronze" },
  locked: { type: Boolean, default: false }
})

const TIER_LABELS = { bronze: "bronze", silver: "argent", gold: "or", prism: "prisme" }

const paths = computed(() => achievementIconPaths(props.achievementKey, props.icon))
const tierName = computed(() => (TIER_LABELS[props.tier] ? props.tier : "bronze"))
const label = computed(() => `Médaille ${TIER_LABELS[tierName.value]}${props.locked ? ", verrouillée" : ""}`)
</script>

<template>
  <span
    class="trophee-medaille"
    :class="[`trophee-${tierName}`, { 'trophee-verrouille': locked }]"
    role="img"
    :aria-label="label"
  >
    <i class="trophee-face"></i>
    <i class="trophee-foil"></i>
    <svg class="trophee-glyph" viewBox="0 0 24 24" fill="none" aria-hidden="true">
      <path
        v-for="(d, i) in paths"
        :key="i"
        :d="d"
        stroke="currentColor"
        stroke-width="1.7"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
  </span>
</template>

<style scoped>
.trophee-medaille {
  position: relative;
  flex: none;
  width: 64px;
  height: 72px;
  display: grid;
  place-items: center;
  /* Les variables de rang : filet (rim), fond (face), encre du glyphe. */
  --trophee-rim: linear-gradient(160deg, var(--bronze-light), var(--bronze));
  --trophee-face: linear-gradient(160deg, #a4703a, #6b4522);
  --trophee-ink: var(--ink);
  filter: drop-shadow(0 2px 4px rgba(0, 0, 0, 0.5));
}
.trophee-medaille::before,
.trophee-face,
.trophee-foil {
  clip-path: polygon(50% 0, 100% 25%, 100% 75%, 50% 100%, 0 75%, 0 25%);
}
.trophee-medaille::before {
  content: "";
  position: absolute;
  inset: 0;
  background: var(--trophee-rim);
}
.trophee-face {
  position: absolute;
  inset: 3px;
  background: var(--trophee-face);
}
.trophee-foil {
  position: absolute;
  inset: 3px;
  background: linear-gradient(115deg, transparent 32%, rgba(255, 255, 255, 0.4) 47%, transparent 62%);
  background-size: 300% 100%;
  background-position: 82% 0;
  opacity: 0;
  pointer-events: none;
}
.trophee-glyph {
  position: relative;
  width: 30px;
  height: 30px;
  color: var(--trophee-ink);
  filter: drop-shadow(0 1px 0 rgba(0, 0, 0, 0.45));
}

/* Rangs : bronze, puis argent, puis or, adaptés à la palette de la Forge. */
.trophee-bronze {
  --trophee-rim: linear-gradient(160deg, #d8a468, #7c4f24);
  --trophee-face: linear-gradient(160deg, #a4703a, #5f3d1d);
  --trophee-ink: #fff3e0;
}
.trophee-silver {
  --trophee-rim: linear-gradient(160deg, #eef1f6, #7f8794);
  --trophee-face: linear-gradient(160deg, #8d94a0, #4d535d);
  --trophee-ink: #f4f6fa;
}
.trophee-gold {
  --trophee-rim: linear-gradient(160deg, var(--bronze-light), #8a6a2c);
  --trophee-face: linear-gradient(160deg, var(--order), #6a4d10);
  --trophee-ink: #fff8e4;
}
/* Or : reflet foil fixe, discret. */
.trophee-gold .trophee-foil {
  opacity: 0.55;
}
/* Prisme : médaille irisée, teinte qui tourne + balayage foil. */
.trophee-prism {
  --trophee-rim: linear-gradient(160deg, var(--mind), var(--calm), var(--chaos));
  --trophee-face: linear-gradient(
    150deg,
    var(--fury),
    var(--order),
    var(--body),
    var(--calm),
    var(--mind),
    var(--chaos)
  );
  --trophee-ink: #fff;
}
.trophee-prism .trophee-face {
  animation: trophee-teinte 9s linear infinite;
}
.trophee-prism .trophee-foil {
  opacity: 0.75;
  animation: trophee-reflet 5.5s ease-in-out infinite;
}
@keyframes trophee-teinte {
  to {
    filter: hue-rotate(360deg);
  }
}
@keyframes trophee-reflet {
  0%,
  52% {
    background-position: 130% 0;
  }
  88%,
  100% {
    background-position: -30% 0;
  }
}

/* Verrouillée : atténuée, filet et fond ternes, sans reflet ni animation. */
.trophee-verrouille {
  filter: none;
  opacity: 0.55;
  --trophee-rim: var(--line);
  --trophee-face: var(--bg-sunken);
  --trophee-ink: var(--ink-muted);
}
.trophee-verrouille .trophee-glyph {
  opacity: 0.7;
  filter: none;
}
.trophee-verrouille .trophee-face {
  animation: none;
}
.trophee-verrouille .trophee-foil {
  display: none;
}
@media (prefers-reduced-motion: reduce) {
  .trophee-prism .trophee-face,
  .trophee-prism .trophee-foil {
    animation: none;
  }
  .trophee-prism .trophee-foil {
    opacity: 0.45;
  }
}
</style>
