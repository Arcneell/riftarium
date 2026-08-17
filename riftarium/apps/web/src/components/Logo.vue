<template>
  <svg viewBox="0 0 240 240" class="logo" aria-hidden="true">
    <defs>
      <linearGradient id="lg-prism" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0" stop-color="#e2574b"/><stop offset=".2" stop-color="#d8a63c"/>
        <stop offset=".4" stop-color="#55b368"/><stop offset=".6" stop-color="#3fbfae"/>
        <stop offset=".8" stop-color="#8f6fe8"/><stop offset="1" stop-color="#e060b8"/>
      </linearGradient>
      <linearGradient id="lg-gold" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#f0e6d2"/><stop offset=".5" stop-color="#c8aa6e"/><stop offset="1" stop-color="#785a28"/>
      </linearGradient>
      <radialGradient id="lg-glow" cx=".5" cy=".5" r=".5">
        <stop offset="0" stop-color="#0ac8b9" stop-opacity=".85"/>
        <stop offset=".55" stop-color="#0397ab" stop-opacity=".35"/>
        <stop offset="1" stop-color="#0397ab" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <circle cx="120" cy="120" r="112" fill="#010a13"/>
    <circle cx="120" cy="120" r="112" fill="none" stroke="url(#lg-gold)" stroke-width="5"/>
    <circle cx="120" cy="120" r="100" fill="none" stroke="#785a28" stroke-width="1" opacity=".5"/>
    <path d="M 120 34 A 86 86 0 1 1 119.9 34" fill="none" stroke="url(#lg-prism)"
          stroke-width="7" stroke-linecap="round" stroke-dasharray="460 80" stroke-dashoffset="-30"
          opacity=".92" transform="rotate(118 120 120)"/>
    <circle cx="120" cy="120" r="58" fill="url(#lg-glow)"/>
    <g transform="rotate(-12 120 120)">
      <rect x="92" y="76" width="56" height="82" rx="9" fill="#0a1c33" stroke="url(#lg-gold)" stroke-width="3.5"/>
      <rect x="99" y="83" width="42" height="42" rx="6" fill="none" stroke="#c8aa6e" stroke-width="1.4" opacity=".55"/>
      <circle cx="120" cy="104" r="10" fill="#0ac8b9" opacity=".9"/>
      <circle cx="120" cy="104" r="15" fill="none" stroke="#cdfafa" stroke-width="1.2" opacity=".55"/>
      <rect x="100" y="134" width="40" height="4" rx="2" fill="#c8aa6e" opacity=".75"/>
      <rect x="100" y="143" width="28" height="4" rx="2" fill="#c8aa6e" opacity=".45"/>
    </g>
  </svg>
</template>
