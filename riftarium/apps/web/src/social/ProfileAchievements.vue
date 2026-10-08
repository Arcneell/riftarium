<script setup>
import { computed } from "vue"
import AchievementMedal from "./AchievementMedal.vue"
import RiftPanel from "../ui/RiftPanel.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import { achievementPercent, achievementProgress, formatUnlockedAt, isUnlocked, tierLabel } from "../social.js"

/* Hauts faits du compte : catalogue groupé par famille (groupAchievements), débloqués
   en tête ; un haut fait verrouillé montre sa progression vers le seuil. */
const props = defineProps({
  groups: { type: Array, default: () => [] },
  loading: { type: Boolean, default: false },
  error: { type: String, default: "" },
  /* Faux sur le profil public : seuls les débloqués sont publiés, « n / n » serait trompeur. */
  showTotals: { type: Boolean, default: true },
  /* Texte quand la liste est vide (le profil public ne publie que les débloqués). */
  emptyText: { type: String, default: "Aucun haut fait au catalogue pour l'instant." }
})

const unlocked = computed(() => props.groups.reduce((sum, group) => sum + group.unlocked, 0))
const total = computed(() => props.groups.reduce((sum, group) => sum + group.total, 0))
</script>

<template>
  <RiftPanel accent="var(--bronze)">
    <template #title>
      Hauts faits
      <span v-if="total" class="profil-hf-compte">{{ showTotals ? `${unlocked} / ${total}` : unlocked }}</span>
    </template>
    <p class="profil-hf-note">
      Les hauts faits de parties ne comptent que les parties suivies confirmées par les deux joueurs ou terminées par un
      abandon, jamais la partie libre.
    </p>
    <p v-if="error" class="profil-hf-erreur" role="alert">{{ error }}</p>
    <div v-else-if="loading" role="status">
      <span class="sr-only">Chargement des hauts faits…</span>
      <RiftSkeleton :lines="4" />
    </div>
    <template v-else>
      <div v-for="group in groups" :key="group.family" class="profil-famille">
        <h3 class="profil-famille-titre">
          {{ group.label }}
          <span class="profil-hf-compte">{{ showTotals ? `${group.unlocked} / ${group.total}` : group.unlocked }}</span>
        </h3>
        <ul class="profil-medailles">
          <li
            v-for="item in group.items"
            :key="item.key"
            class="profil-medaille"
            :class="{ 'profil-medaille--verrouille': !isUnlocked(item) }"
          >
            <AchievementMedal
              :achievement-key="item.key"
              :icon="item.icon"
              :tier="item.tier"
              :locked="!isUnlocked(item)"
            />
            <span class="profil-medaille-corps">
              <b class="profil-medaille-titre">{{ item.title }}</b>
              <span class="profil-medaille-texte">{{ item.description }}</span>
              <span v-if="isUnlocked(item)" class="profil-medaille-meta">
                {{ tierLabel(item.tier) }}
                <template v-if="formatUnlockedAt(item.unlocked_at)">
                  · débloqué le {{ formatUnlockedAt(item.unlocked_at) }}
                </template>
              </span>
              <template v-else>
                <span class="profil-jauge" aria-hidden="true">
                  <span class="profil-jauge-fill" :style="{ width: `${achievementPercent(item)}%` }"></span>
                </span>
                <span class="profil-medaille-meta">{{ achievementProgress(item) }}</span>
              </template>
            </span>
          </li>
        </ul>
      </div>
      <p v-if="!groups.length" class="profil-hf-note">{{ emptyText }}</p>
    </template>
  </RiftPanel>
</template>

<style scoped>
.profil-hf-compte {
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.12em;
  color: var(--ink-muted);
}
.profil-hf-note {
  margin: 0 0 var(--space-4);
  color: var(--ink-muted);
}
.profil-hf-erreur {
  margin: 0;
  color: var(--blood-text);
}
.profil-famille + .profil-famille {
  margin-top: var(--space-5);
}
/* h3 : encre et police posées ici (le style de base le passe en bronze). */
.profil-famille-titre {
  margin: 0 0 var(--space-3);
  font-family: var(--font-label);
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--bronze-light);
}
.profil-medailles {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: var(--space-3);
  margin: 0;
  padding: 0;
  list-style: none;
}
.profil-medaille {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  padding: var(--space-2);
  background: var(--bg-sunken);
  box-shadow: inset 0 0 0 1px var(--line);
}
.profil-medaille-corps {
  display: grid;
  gap: 2px;
  min-width: 0;
}
.profil-medaille-titre {
  color: var(--ink);
  font-weight: 600;
}
.profil-medaille--verrouille .profil-medaille-titre {
  color: var(--ink-muted);
}
.profil-medaille-texte {
  font-size: 14px;
  color: var(--ink-muted);
}
.profil-medaille-meta {
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--ink-muted);
}
.profil-jauge {
  display: block;
  height: 6px;
  margin-top: var(--space-1);
  background: var(--bg);
  box-shadow: inset 0 0 0 1px var(--line);
}
.profil-jauge-fill {
  display: block;
  height: 100%;
  background: var(--bronze);
}
</style>
