<script setup>
defineProps({
  name: { type: String, required: true },
  size: { type: [Number, String], default: 22 }
})
</script>

<template>
  <svg
    class="icon"
    :width="size"
    :height="size"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.7"
    stroke-linecap="round"
    stroke-linejoin="round"
    aria-hidden="true"
  >
    <!-- chevron bas (menu déroulant) -->
    <g v-if="name === 'chevron'">
      <path d="M6 9.5l6 6 6-6" />
    </g>
    <!-- appareil photo (scanner de cartes) -->
    <g v-else-if="name === 'camera'">
      <path
        d="M4 8.2h3.2l1.6-2.4h6.4l1.6 2.4H20a1.6 1.6 0 0 1 1.6 1.6v8.6A1.6 1.6 0 0 1 20 20H4a1.6 1.6 0 0 1-1.6-1.6V9.8A1.6 1.6 0 0 1 4 8.2Z"
      />
      <circle cx="12" cy="13.6" r="3.4" />
    </g>
    <!-- accueil -->
    <g v-else-if="name === 'home'">
      <path d="M3.5 11.2 12 4l8.5 7.2" />
      <path d="M6 9.6V20h12V9.6" />
      <path d="M10 20v-5.4h4V20" />
    </g>
    <!-- cartes (éventail) -->
    <g v-else-if="name === 'cards'">
      <rect x="7.6" y="3.6" width="10.4" height="14.8" rx="1.4" />
      <path d="M5.6 6.6 4 7.1a1.2 1.2 0 0 0-.8 1.5l3.4 11a1.2 1.2 0 0 0 1.5.8l6-1.8" />
    </g>
    <!-- decks (pile) -->
    <g v-else-if="name === 'decks'">
      <path d="M12 3.6 20.4 8 12 12.4 3.6 8 12 3.6Z" />
      <path d="M3.6 12 12 16.4 20.4 12" />
      <path d="M3.6 16 12 20.4 20.4 16" />
    </g>
    <!-- collection (classeur) -->
    <g v-else-if="name === 'collection'">
      <rect x="4.4" y="3.6" width="15.2" height="16.8" rx="1.4" />
      <path d="M12 3.6v16.8" />
      <path d="M7 8h2.6M7 12h2.6M14.4 8H17M14.4 12H17" />
    </g>
    <!-- règles (livre ouvert) -->
    <g v-else-if="name === 'rules'">
      <path d="M12 6.4c-2-1.6-4.8-2-8-1.6v13.6c3.2-.4 6 0 8 1.6 2-1.6 4.8-2 8-1.6V4.8c-3.2-.4-6 0-8 1.6Z" />
      <path d="M12 6.4V20" />
    </g>
    <!-- jouer (épées croisées) -->
    <g v-else-if="name === 'play'">
      <path d="M4 4l9.6 9.6M4 4h3.4L17 13.6M4 4v3.4" />
      <path d="M20 4l-9.6 9.6M20 4h-3.4M20 4v3.4" />
      <path d="M8.4 15.6 5.2 18.8M15.6 15.6l3.2 3.2" />
    </g>
    <!-- compte (silhouette) -->
    <g v-else-if="name === 'user'">
      <circle cx="12" cy="8.4" r="3.8" />
      <path d="M4.4 20.4c.8-3.8 3.8-6 7.6-6s6.8 2.2 7.6 6" />
    </g>
    <!-- replier le rail -->
    <g v-else-if="name === 'collapse'">
      <path d="M14.6 6.4 9 12l5.6 5.6" />
      <path d="M19.4 6.4 13.8 12l5.6 5.6" opacity=".5" />
    </g>
    <!-- loupe -->
    <g v-else-if="name === 'search'">
      <circle cx="10.4" cy="10.4" r="6.2" />
      <path d="M15 15.2 20.4 20.6" />
    </g>
    <!-- cœur (likes) -->
    <g v-else-if="name === 'heart'">
      <path
        d="M12 19.4s-7.2-4.4-8.8-9.1C2.2 7.4 3.8 5 6.4 5c1.6 0 2.6.9 3.6 2.2C11 5.9 12 5 13.6 5c2.6 0 4.2 2.4 3.2 5.3-1.6 4.7-8.8 9.1-8.8 9.1Z"
        fill="currentColor"
        stroke="none"
      />
    </g>
    <!-- cœur en contour (wishlist, état vide) -->
    <g v-else-if="name === 'heart-line'">
      <path
        d="M12 19.4s-7.2-4.4-8.8-9.1C2.2 7.4 3.8 5 6.4 5c1.6 0 2.6.9 3.6 2.2C11 5.9 12 5 13.6 5c2.6 0 4.2 2.4 3.2 5.3-1.6 4.7-8.8 9.1-8.8 9.1Z"
      />
    </g>
    <!-- œil (vues) -->
    <g v-else-if="name === 'eye'">
      <path d="M2.6 12s3.4-6.2 9.4-6.2S21.4 12 21.4 12s-3.4 6.2-9.4 6.2S2.6 12 2.6 12Z" />
      <circle cx="12" cy="12" r="2.4" />
    </g>
    <!-- menu burger -->
    <g v-else-if="name === 'menu'">
      <path d="M4.2 7h15.6" />
      <path d="M4.2 12h15.6" />
      <path d="M4.2 17h15.6" />
    </g>
    <!-- croix (fermeture) -->
    <g v-else-if="name === 'x'">
      <path d="M6 6l12 12" />
      <path d="M18 6 6 18" />
    </g>
    <!-- flèche -->
    <g v-else-if="name === 'arrow'">
      <path d="M4.4 12h15.2" />
      <path d="M13.4 5.8 20.6 12l-7.2 6.2" />
    </g>
  </svg>
</template>
