<script setup>
import { onMounted, ref } from "vue";
import { api } from "../api.js";

/* Deux rangées de cartes qui défilent en continu, en sens opposés. */
const rows = ref([[], []]);

onMounted(async () => {
  try {
    const [a, b] = await Promise.all([
      api("/api/cards?set_id=OGN&size=14&page=2"),
      api("/api/cards?set_id=SFD&size=14&page=3")
    ]);
    rows.value = [a.items, b.items];
  } catch { /* la rivière reste vide, la page vit sans */ }
});

const thumb = url => url ? url.replace(/w=\d+/, "w=260") : url;
</script>

<template>
  <div class="river" aria-hidden="true" v-if="rows[0].length">
    <div class="river-row" v-for="(row, i) in rows" :key="i" :class="{ reverse: i === 1 }">
      <div class="river-track">
        <img v-for="card in [...row, ...row]" :key="card.id + Math.random()"
             :src="thumb(card.image_url)" alt="" loading="lazy"
             :class="{ landscape: card.orientation === 'landscape' }" />
      </div>
    </div>
  </div>
</template>
