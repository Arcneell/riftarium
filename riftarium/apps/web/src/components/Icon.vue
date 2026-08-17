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
    <!-- deux cartes superposées -->
    <g v-if="name === 'cards'">
      <rect x="3.2" y="5.5" width="12.2" height="15.2" rx="1.8" />
      <path d="M8.2 3.4h11.4A1.8 1.8 0 0 1 21.4 5.2v13.4" />
    </g>
    <!-- livre ouvert -->
    <g v-else-if="name === 'book'">
      <path d="M4 5.2c2.2-1.2 4.6-1.2 6.8 0v14c-2.2-1.2-4.6-1.2-6.8 0V5.2Z" />
      <path d="M13.2 5.2c2.2-1.2 4.6-1.2 6.8 0v14c-2.2-1.2-4.6-1.2-6.8 0V5.2Z" />
      <path d="M12 5.4v13.8" />
    </g>
    <!-- pile de cartes (deck) -->
    <g v-else-if="name === 'layers'">
      <path d="M12 3.2 21 7.4 12 11.6 3 7.4 12 3.2Z" />
      <path d="M3 12.2 12 16.4 21 12.2" />
      <path d="M3 16.8 12 21 21 16.8" />
    </g>
    <!-- coffre / inventaire -->
    <g v-else-if="name === 'box'">
      <path d="M3.4 8.2 12 4.2l8.6 4v10.6L12 20.8 3.4 18.8V8.2Z" />
      <path d="M12 12.4V20.8" />
      <path d="M3.4 8.2 12 12.4l8.6-4.2" />
      <path d="M8.2 6.2 15.8 9.6" />
    </g>
    <!-- communauté -->
    <g v-else-if="name === 'users'">
      <circle cx="9" cy="8" r="3.1" />
      <path d="M3.4 19.2c.4-3.4 2.6-5.2 5.6-5.2s5.2 1.8 5.6 5.2" />
      <circle cx="16.6" cy="8.6" r="2.4" />
      <path d="M15.4 14.2c2.4.2 4.2 1.7 4.8 5" />
    </g>
    <!-- code source -->
    <g v-else-if="name === 'code'">
      <path d="M8.2 6.4 3.4 12l4.8 5.6" />
      <path d="M15.8 6.4 20.6 12l-4.8 5.6" />
      <path d="M13.4 4.6 10.6 19.4" />
    </g>
    <!-- loupe -->
    <g v-else-if="name === 'search'">
      <circle cx="10.4" cy="10.4" r="6.2" />
      <path d="M15 15.2 20.4 20.6" />
    </g>
    <!-- menu burger -->
    <g v-else-if="name === 'menu'">
      <path d="M4.2 7h15.6" />
      <path d="M4.2 12h15.6" />
      <path d="M4.2 17h15.6" />
    </g>
    <!-- flèche -->
    <g v-else-if="name === 'arrow'">
      <path d="M4.4 12h15.2" />
      <path d="M13.4 5.8 20.6 12l-7.2 6.2" />
    </g>
  </svg>
</template>
