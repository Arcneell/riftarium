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
