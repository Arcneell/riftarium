<script setup>
import RiftPanel from "../ui/RiftPanel.vue"
import { PRIVACY_TOGGLES } from "../social.js"

/* Confidentialité : quatre interrupteurs Forgés, chacun une vraie case à cocher
   (masquée, mais focalisable et dite par le lecteur d'écran) dans son libellé.
   L'état et l'enregistrement restent dans la page : on ne fait qu'émettre la clé. */
defineProps({
  /* { show_achievements: bool, show_stats: bool, … } */
  values: { type: Object, required: true },
  /* Clé en cours d'enregistrement ("" au repos) : toutes les cases sont figées. */
  saving: { type: String, default: "" },
  error: { type: String, default: "" },
  ok: { type: String, default: "" },
  publicPath: { type: String, required: true }
})
const emit = defineEmits(["toggle"])
</script>

<template>
  <RiftPanel title="Confidentialité" accent="var(--bronze)">
    <p class="compte-intro">
      Ce que votre <RouterLink :to="publicPath">profil public</RouterLink> montre aux autres joueurs.
    </p>
    <ul class="compte-reglages">
      <li v-for="toggle in PRIVACY_TOGGLES" :key="toggle.key">
        <label class="compte-switch">
          <input
            class="compte-switch-input sr-only"
            type="checkbox"
            :checked="Boolean(values[toggle.key])"
            :disabled="Boolean(saving)"
            @change="emit('toggle', toggle.key)"
          />
          <span class="compte-switch-piste" aria-hidden="true"><span class="compte-switch-bille"></span></span>
          <span class="compte-switch-texte">
            <b class="compte-switch-titre">{{ toggle.label }}</b>
            <span class="compte-switch-aide">{{ toggle.hint }}</span>
          </span>
        </label>
      </li>
    </ul>
    <p v-if="error" class="compte-erreur" role="alert">{{ error }}</p>
    <p v-else-if="saving" class="compte-attente" role="status">Enregistrement…</p>
    <p v-else-if="ok" class="compte-succes" role="status">{{ ok }}</p>
  </RiftPanel>
</template>

<style scoped>
.compte-intro {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
}
.compte-reglages {
  display: grid;
  gap: var(--space-2);
  margin: 0;
  padding: 0;
  list-style: none;
}
.compte-switch {
  position: relative;
  display: flex;
  align-items: flex-start;
  gap: var(--space-3);
  min-height: 44px;
  padding: var(--space-2) 0;
  cursor: pointer;
}
.compte-switch-piste {
  position: relative;
  flex: none;
  width: 44px;
  height: 24px;
  margin-top: 2px;
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  transition:
    background-color var(--t-fast),
    border-color var(--t-fast);
}
.compte-switch-bille {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 16px;
  height: 16px;
  background: var(--ink-muted);
  transition:
    transform var(--t-fast),
    background-color var(--t-fast);
}
.compte-switch-input:checked + .compte-switch-piste {
  background: color-mix(in srgb, var(--bg-sunken), var(--blood) 35%);
  border-color: var(--blood);
}
.compte-switch-input:checked + .compte-switch-piste .compte-switch-bille {
  transform: translateX(20px);
  background: var(--ink);
}
/* La case est masquée : son focus se reporte sur la piste visible. */
.compte-switch-input:focus-visible + .compte-switch-piste {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.compte-switch-input:disabled + .compte-switch-piste {
  opacity: 0.6;
}
.compte-switch:has(.compte-switch-input:disabled) {
  cursor: progress;
}
.compte-switch-texte {
  display: grid;
  gap: 2px;
  min-width: 0;
}
.compte-switch-titre {
  color: var(--ink);
  font-weight: 600;
}
.compte-switch-aide {
  font-size: 14px;
  color: var(--ink-muted);
}
.compte-erreur,
.compte-attente,
.compte-succes {
  margin: var(--space-3) 0 0;
  font-size: 14px;
}
.compte-erreur {
  color: var(--blood-text);
}
.compte-attente {
  color: var(--ink-muted);
}
.compte-succes {
  color: var(--bronze-light);
}
</style>
