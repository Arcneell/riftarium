<script setup>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { api, session } from "../api.js";

const router = useRouter();
const decks = ref([]);
const error = ref("");

async function load() {
  try {
    decks.value = await api("/api/community/decks");
  } catch (e) {
    error.value = e.message;
  }
}

async function toggleLike(deck) {
  if (!session.token) {
    router.push({ path: "/connexion", query: { suite: "/communaute" } });
    return;
  }
  try {
    const result = await api(`/api/decks/${deck.id}/like`, { method: "POST" });
    deck.likes = result.likes;
    deck.liked_by_me = result.liked_by_me;
  } catch (e) {
    error.value = e.message;
  }
}

function okCount(deck) {
  return deck.checks.filter(c => c.ok).length;
}

onMounted(load);
</script>

<template>
  <div class="page-banner"
       style="--banner: url('https://cmsassets.rgpub.io/sanity/images/dsfx7636/news_live/91a720561b6cd9c649a9148782f34d96e78cd894-4320x2430.jpg?auto=format&w=1600')">
    <div class="wrap">
      <p class="eyebrow">Communauté</p>
      <h2>Decks partagés</h2>
      <p class="lead">
        Les decks publics des membres, triés par popularité. Chaque publication passe par la
        modération automatique avant d'apparaître ici.
      </p>
    </div>
    <span class="splash-credit">Visuel officiel Riftbound — © Riot Games</span>
  </div>
  <section>
    <div class="wrap">
      <p v-if="error" class="error">{{ error }}</p>

      <div class="panel" v-for="deck in decks" :key="deck.id" style="margin-bottom:16px">
        <div style="display:flex; gap:14px; align-items:center; flex-wrap:wrap">
          <div style="flex:1">
            <h3>{{ deck.name }}</h3>
            <p class="muted mono" style="font-size:.76rem">
              par {{ deck.owner }} · {{ deck.card_count }} cartes ·
              {{ deck.format === "tournament" ? "tournoi" : "libre" }} ·
              validation {{ okCount(deck) }}/{{ deck.checks.length }}
            </p>
            <p class="muted" style="font-size:.88rem; margin-top:6px" v-if="deck.description">{{ deck.description }}</p>
          </div>
          <button class="btn btn-ghost btn-sm" :aria-pressed="deck.liked_by_me"
                  :style="deck.liked_by_me ? 'color:var(--chaos)' : ''" @click="toggleLike(deck)">
            ♥ {{ deck.likes }}
          </button>
        </div>
      </div>
      <p v-if="!decks.length && !error" class="muted">
        Aucun deck public pour l'instant — soyez le premier à en <RouterLink to="/decks">publier un</RouterLink> !
      </p>
    </div>
  </section>
</template>
