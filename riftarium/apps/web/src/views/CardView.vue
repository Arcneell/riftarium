<script setup>
import { onMounted, ref } from "vue";
import { useRoute } from "vue-router";
import { api, session, DOMAINS, TYPES, RARITIES } from "../api.js";

const route = useRoute();
const card = ref(null);
const error = ref("");
const qty = ref(1);
const saved = ref("");

onMounted(async () => {
  try {
    card.value = await api(`/api/cards/${route.params.id}`);
  } catch (e) {
    error.value = e.message;
  }
});

async function addToCollection() {
  saved.value = "";
  try {
    const response = await api(`/api/collection/${card.value.id}`, {
      method: "PUT",
      body: { qty: qty.value }
    });
    saved.value = `Enregistré : ${response.qty} exemplaire(s) dans votre collection.`;
  } catch (e) {
    error.value = e.message;
  }
}
</script>

<template>
  <section>
    <div class="wrap">
      <p style="margin-bottom:20px"><RouterLink to="/cartes">← Retour à la cartothèque</RouterLink></p>
      <p v-if="error" class="error">{{ error }}</p>

      <div class="card-sheet" v-if="card">
        <div>
          <img class="full" :class="{ landscape: card.orientation === 'landscape' }"
               :src="card.image_url" :alt="`Carte Riftbound : ${card.name}`" />
          <p class="card-credit">{{ card.riftbound_id.toUpperCase() }} · Illustration : {{ card.artist }} · © Riot Games</p>
        </div>

        <div>
          <p class="eyebrow">{{ card.set_id }} · {{ RARITIES[card.rarity] || card.rarity }}</p>
          <h1>{{ card.name }}</h1>

          <div class="stat-row">
            <div class="stat">Type<b>{{ TYPES[card.type] || card.type }}</b></div>
            <div class="stat">Domaine<b :style="{ color: DOMAINS[card.domains?.[0]]?.color }">
              {{ card.domains?.map(d => DOMAINS[d]?.label || d).join(" / ") || "—" }}</b></div>
            <div class="stat" v-if="card.energy !== null">Énergie<b>{{ card.energy }}</b></div>
            <div class="stat" v-if="card.might !== null">Puissance<b>{{ card.might }}</b></div>
            <div class="stat" v-if="card.power !== null">Pouvoir<b>{{ card.power }}</b></div>
          </div>

          <div class="rules-text" v-if="card.text">
            <p>{{ card.text }}</p>
            <p class="muted" style="font-size:.8rem; margin-top:8px">Texte officiel anglais — le français arrivera avec l'API Riot.</p>
          </div>
          <p class="muted" v-if="card.flavour" style="font-style:italic; margin:12px 0">« {{ card.flavour }} »</p>

          <div class="panel" style="margin-top:22px" v-if="session.token">
            <h3 style="margin-bottom:12px">Ma collection</h3>
            <div style="display:flex; gap:12px; align-items:center">
              <input type="number" min="0" max="999" v-model.number="qty" style="width:90px" aria-label="Quantité" />
              <button class="btn btn-gold btn-sm" @click="addToCollection">Enregistrer la quantité</button>
            </div>
            <p v-if="saved" class="success">{{ saved }}</p>
          </div>
          <p v-else class="muted" style="margin-top:22px">
            <RouterLink to="/connexion">Connectez-vous</RouterLink> pour ajouter cette carte à votre collection.
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
