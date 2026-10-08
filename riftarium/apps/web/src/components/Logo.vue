<script setup>
import { useId } from "vue"

/* Sceau de forge (charte « Forge noxienne ») : octogone aux angles coupés cerclé de
   bronze, carte fendue par la faille rouge du Rift. Mêmes tracés que public/favicon.svg
   et assets/logo.svg (racine du dépôt) : les garder alignés.
   Le logo est rendu deux fois par page (rail et pied) : un suffixe par instance rend
   chaque dégradé unique, sinon le second SVG reprendrait les `defs` du premier. */
const uid = useId()
const bronze = `lg-bronze-${uid}`
const blood = `lg-sang-${uid}`
const glow = `lg-lueur-${uid}`
</script>

<template>
  <svg viewBox="0 0 120 120" class="logo" aria-hidden="true">
    <defs>
      <linearGradient :id="bronze" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#e6cfa6" />
        <stop offset=".55" stop-color="#b08d5f" />
        <stop offset="1" stop-color="#6e5536" />
      </linearGradient>
      <linearGradient :id="blood" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#ff7a5c" />
        <stop offset=".5" stop-color="#d23a33" />
        <stop offset="1" stop-color="#8e1b20" />
      </linearGradient>
      <filter :id="glow" x="-50%" y="-50%" width="200%" height="200%">
        <feGaussianBlur stdDeviation="3" result="flou" />
        <feMerge>
          <feMergeNode in="flou" />
          <feMergeNode in="SourceGraphic" />
        </feMerge>
      </filter>
    </defs>
    <polygon
      data-part="sceau"
      points="34,4 86,4 116,34 116,86 86,116 34,116 4,86 4,34"
      fill="#0d0d0f"
      :stroke="`url(#${bronze})`"
      stroke-width="5"
    />
    <polygon
      points="37,13 83,13 107,37 107,83 83,107 37,107 13,83 13,37"
      fill="none"
      stroke="#d6b98c"
      stroke-width="1"
      opacity=".35"
    />
    <g transform="rotate(-8 60 60)">
      <path data-part="carte" d="M40 30 H80 V90 H40 Z" fill="#17120f" :stroke="`url(#${bronze})`" stroke-width="3.5" />
      <path
        data-part="faille"
        d="M63 26 L54 50 L64 58 L52 94"
        fill="none"
        :stroke="`url(#${blood})`"
        stroke-width="6"
        stroke-linejoin="miter"
        :filter="`url(#${glow})`"
      />
    </g>
  </svg>
</template>
