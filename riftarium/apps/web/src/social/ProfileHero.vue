<script setup>
import UserAvatar from "../components/UserAvatar.vue"

/* En-tête Forgé d'un profil (le mien sur /profil, celui d'un joueur sur /u/:handle) :
   grand portrait, pseudo en h1 (ellipse, pseudo complet au survol), bio, mentions
   (ancienneté, abonnés…) et un emplacement d'actions propre à chaque page. */
defineProps({
  handle: { type: String, required: true },
  avatarUrl: { type: String, default: "" },
  bio: { type: String, default: "" },
  /* Mentions courtes affichées sous la bio, dans l'ordre (chaînes vides ignorées). */
  meta: { type: Array, default: () => [] }
})
</script>

<template>
  <header class="profil-hero">
    <UserAvatar class="profil-hero-portrait" :src="avatarUrl || ''" :handle="handle" :size="96" />
    <div class="profil-hero-corps">
      <h1 class="profil-hero-pseudo" :title="handle">{{ handle }}</h1>
      <p v-if="bio" class="profil-hero-bio">{{ bio }}</p>
      <p v-else class="profil-hero-bio profil-hero-vide">Pas encore de bio.</p>
      <p v-if="meta.filter(Boolean).length" class="profil-hero-meta">
        <span v-for="item in meta.filter(Boolean)" :key="item" class="profil-hero-mention">{{ item }}</span>
      </p>
    </div>
    <div v-if="$slots.actions" class="profil-hero-actions">
      <slot name="actions" />
    </div>
  </header>
</template>

<style scoped>
.profil-hero {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  align-items: center;
  gap: var(--space-5);
  padding: var(--space-5);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow: inset 0 0 0 1px var(--line);
  clip-path: polygon(
    var(--cut) 0,
    100% 0,
    100% calc(100% - var(--cut)),
    calc(100% - var(--cut)) 100%,
    0 100%,
    0 var(--cut)
  );
}
.profil-hero p {
  margin: 0;
}
.profil-hero-portrait {
  border-width: 2px;
}
.profil-hero-corps {
  display: grid;
  gap: var(--space-2);
  min-width: 0;
}
/* main.css colore, anime et dimensionne les h1 : on neutralise. */
.profil-hero-pseudo {
  margin: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  background: none;
  color: var(--ink);
  animation: none;
  font-family: var(--font-display);
  font-size: clamp(26px, 4vw, 38px);
  font-weight: 700;
  letter-spacing: 0.04em;
}
.profil-hero-bio {
  color: var(--ink);
  overflow-wrap: anywhere;
}
.profil-hero-vide,
.profil-hero-meta {
  color: var(--ink-muted);
}
.profil-hero-meta {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-1) var(--space-4);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.profil-hero-mention {
  white-space: nowrap;
}
.profil-hero-actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: var(--space-2);
}

@media (max-width: 759px) {
  .profil-hero {
    grid-template-columns: auto minmax(0, 1fr);
    gap: var(--space-4);
  }
  .profil-hero-actions {
    grid-column: 1 / -1;
    justify-content: flex-start;
  }
}
</style>
