<script setup>
/* Bandeau global de la coquille, posé en haut du contenu (vérification d'e-mail,
   page hors ligne, traceurs). Filet gauche de bronze pour une information, de sang
   pour une action requise. Le rôle ARIA et le libellé arrivent par les attributs. */
defineProps({
  tone: { type: String, default: "info", validator: (value) => ["info", "action"].includes(value) }
})
</script>

<template>
  <div class="bandeau-cadre" :class="`bandeau-cadre--${tone}`">
    <div class="bandeau-texte"><slot /></div>
    <div v-if="$slots.actions" class="bandeau-actions"><slot name="actions" /></div>
  </div>
</template>

<style scoped>
.bandeau-cadre {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3) var(--space-4);
  margin: var(--space-3) var(--space-5) 0;
  padding: var(--space-3) var(--space-4);
  background: var(--bg-raised);
  border-left: 3px solid var(--bronze);
  box-shadow: inset 0 0 0 1px var(--line);
  font-family: var(--font-body);
  font-size: 14px;
  line-height: 1.45;
  color: var(--ink);
}
.bandeau-cadre--action {
  border-left-color: var(--blood);
}
.bandeau-texte {
  flex: 1 1 280px;
  min-width: 0;
}
.bandeau-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
  flex-shrink: 0;
}
@media (max-width: 560px) {
  .bandeau-cadre {
    margin: var(--space-2) var(--space-4) 0;
    padding: var(--space-2) var(--space-3);
    font-size: 13px;
  }
  .bandeau-actions {
    flex: 1 1 100%;
    justify-content: space-between;
  }
}
</style>
