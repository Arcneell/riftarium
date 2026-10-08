<script setup>
import { ref } from "vue"
import RiftText from "../ui/RiftText.vue"
import LearnRuneDemo from "./LearnRuneDemo.vue"
import { ABCD_PHASES, LEARN_INTRO } from "./learn.js"

/* Rendu d'un bloc de leçon (voir learn.js). Les cartes agrandies sont signalées par
   `zoom` : la page ouvre CardZoom. */
const props = defineProps({ block: { type: Object, required: true } })
const emit = defineEmits(["zoom"])

/* La sélection des « types » reste locale au bloc. */
const selectedType = ref(props.block.type === "types" ? (props.block.items[0]?.key ?? null) : null)
</script>

<template>
  <h2 v-if="block.type === 'h'" class="lecon-h">{{ block.text }}</h2>

  <p v-else-if="block.type === 'p'" class="lecon-p"><RiftText rules :text="block.text" /></p>

  <div v-else-if="block.type === 'stat'" class="lecon-stat">
    <b class="lecon-stat-value">{{ block.value }}</b>
    <div>
      <p class="lecon-stat-label">{{ block.label }}</p>
      <p class="lecon-p"><RiftText rules :text="block.text" /></p>
    </div>
  </div>

  <ul v-else-if="block.type === 'ul'" class="lecon-list">
    <li v-for="(item, j) in block.items" :key="j"><RiftText rules :text="item" /></li>
  </ul>

  <ol v-else-if="block.type === 'ol'" class="lecon-list lecon-numbered">
    <li v-for="(item, j) in block.items" :key="j"><RiftText rules :text="item" /></li>
  </ol>

  <div v-else-if="block.type === 'table'" class="lecon-table-wrap">
    <table class="lecon-table">
      <thead>
        <tr>
          <th v-for="header in block.headers" :key="header" scope="col">{{ header }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="(row, r) in block.rows" :key="r">
          <td v-for="(cell, c) in row" :key="c"><RiftText rules :text="cell" /></td>
        </tr>
      </tbody>
    </table>
  </div>

  <aside v-else-if="block.type === 'note'" class="lecon-note" :class="`lecon-note--${block.kind}`">
    <p class="lecon-note-title">{{ block.title }}</p>
    <p class="lecon-note-text"><RiftText rules :text="block.text" /></p>
  </aside>

  <ol v-else-if="block.type === 'steps'" class="lecon-steps">
    <li v-for="(step, s) in block.items" :key="s">
      <strong class="lecon-step-title">{{ step.title }}</strong>
      <p><RiftText rules :text="step.text" /></p>
    </li>
  </ol>

  <div v-else-if="block.type === 'compare'" class="lecon-compare">
    <div v-for="side in [block.left, block.right]" :key="side.title" class="lecon-compare-col">
      <p class="lecon-kicker">{{ side.kicker }}</p>
      <h3 class="lecon-compare-title">{{ side.title }}</h3>
      <p><RiftText rules :text="side.text" /></p>
      <p class="lecon-recover">{{ side.recover }}</p>
    </div>
  </div>

  <div v-else-if="block.type === 'abcd'" class="lecon-abcd">
    <div v-for="phase in ABCD_PHASES" :key="phase.name" class="lecon-abcd-step">
      <b class="lecon-abcd-letter">{{ phase.letter }}</b>
      <div>
        <strong>{{ phase.name }}</strong>
        <p>{{ phase.text }}</p>
      </div>
    </div>
  </div>

  <div v-else-if="block.type === 'types'" class="lecon-types">
    <div class="lecon-types-grid">
      <button
        v-for="item in block.items"
        :key="item.key"
        type="button"
        class="lecon-type"
        :class="{ 'lecon-type--current': selectedType === item.key, 'lecon-type--wide': item.wide }"
        :aria-pressed="selectedType === item.key"
        :aria-label="item.title"
        @click="selectedType = item.key"
        @dblclick="emit('zoom', item.card)"
      >
        <img :src="item.card.img" :alt="item.title" loading="lazy" decoding="async" />
        <span>{{ item.title }}</span>
      </button>
    </div>
    <template v-for="item in block.items" :key="item.key + '-copy'">
      <div v-show="selectedType === item.key" class="lecon-type-copy">
        <p class="lecon-kicker">{{ item.title }}</p>
        <p><RiftText rules :text="item.text" /></p>
        <button type="button" class="lecon-enlarge" @click="emit('zoom', item.card)">Agrandir</button>
      </div>
    </template>
  </div>

  <div v-else-if="block.type === 'loop'" class="lecon-loop">
    <p class="lecon-kicker">Si vous ne retenez qu'une chose</p>
    <p class="lecon-loop-text">{{ LEARN_INTRO }}</p>
  </div>

  <LearnRuneDemo v-else-if="block.type === 'runes'" />
</template>

<style scoped>
/* h2, h3, table et th : tout est posé ici. */
.lecon-h {
  margin: var(--space-6) 0 var(--space-3);
  padding: 0;
  background: none;
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.lecon-p {
  margin: 0 0 var(--space-3);
  color: var(--ink);
  line-height: 1.6;
}
.lecon-kicker {
  margin: 0 0 var(--space-1);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.lecon-stat {
  display: flex;
  align-items: center;
  gap: var(--space-5);
  margin: var(--space-4) 0;
  padding: var(--space-4) var(--space-5);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-stat-value {
  color: var(--blood-bright);
  font-family: var(--font-display);
  font-size: 64px;
  font-weight: 700;
  line-height: 1;
}
.lecon-stat-label {
  margin: 0 0 var(--space-1);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 16px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.lecon-stat .lecon-p {
  margin: 0;
}
.lecon-list {
  margin: 0 0 var(--space-4);
  padding-left: var(--space-5);
  color: var(--ink);
  line-height: 1.6;
}
.lecon-list li {
  margin-bottom: var(--space-2);
}
.lecon-list li::marker {
  color: var(--bronze);
}
.lecon-table-wrap {
  margin: var(--space-4) 0;
  overflow-x: auto;
}
.lecon-table {
  width: 100%;
  border-collapse: collapse;
  background: none;
  font-size: 15px;
}
.lecon-table th {
  padding: var(--space-2) var(--space-3);
  background: var(--bg-sunken);
  border: 1px solid var(--line);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 15px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-align: left;
  text-transform: uppercase;
}
.lecon-table td {
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--line);
  color: var(--ink);
  vertical-align: top;
}
.lecon-note {
  margin: var(--space-4) 0;
  padding: var(--space-3) var(--space-4);
  background: var(--bg-sunken);
  border-left: 3px solid var(--bronze-light);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-note--tip {
  border-left-color: var(--bronze);
}
.lecon-note--warn {
  border-left-color: var(--blood);
}
.lecon-note-title {
  margin: 0 0 var(--space-1);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.14em;
  text-transform: uppercase;
}
.lecon-note--warn .lecon-note-title {
  color: var(--blood-text);
}
.lecon-note-text {
  margin: 0;
  line-height: 1.55;
}
.lecon-steps,
.lecon-numbered {
  list-style: none;
  margin: 0 0 var(--space-4);
  padding: 0;
  counter-reset: lecon;
}
.lecon-steps li,
.lecon-numbered li {
  position: relative;
  min-height: 36px;
  margin-bottom: var(--space-3);
  padding-left: 48px;
  counter-increment: lecon;
  line-height: 1.55;
}
.lecon-steps li::before,
.lecon-numbered li::before {
  content: counter(lecon);
  position: absolute;
  left: 0;
  top: -2px;
  width: 36px;
  color: var(--bronze);
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: 700;
  line-height: 1.2;
  text-align: center;
}
.lecon-step-title {
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 17px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.lecon-steps p {
  margin: var(--space-1) 0 0;
}
.lecon-compare {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-3);
  margin: var(--space-4) 0;
}
.lecon-compare-col {
  padding: var(--space-4);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-compare-title {
  margin: 0 0 var(--space-2);
  padding: 0;
  background: none;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 20px;
  font-weight: 700;
}
.lecon-compare-col p {
  margin: 0 0 var(--space-2);
}
.lecon-recover {
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.1em;
  text-transform: uppercase;
}
.lecon-abcd {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(170px, 1fr));
  gap: var(--space-3);
  margin: var(--space-4) 0;
}
.lecon-abcd-step {
  display: flex;
  gap: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-raised);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-abcd-letter {
  flex: none;
  color: var(--bronze);
  font-family: var(--font-display);
  font-size: 28px;
  font-weight: 700;
  line-height: 1.1;
}
.lecon-abcd-step strong {
  font-family: var(--font-label);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.lecon-abcd-step p {
  margin: var(--space-1) 0 0;
  color: var(--ink-muted);
  font-size: 14px;
  line-height: 1.4;
}
.lecon-types {
  margin: var(--space-4) 0;
}
.lecon-types-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(110px, 1fr));
  gap: var(--space-3);
}
.lecon-type {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-1);
  min-height: 44px;
  padding: var(--space-2);
  background: var(--bg-raised);
  border: 0;
  box-shadow: inset 0 0 0 1px var(--line);
  color: var(--ink);
  font-family: var(--font-label);
  font-size: 15px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  cursor: pointer;
  transition: box-shadow var(--t-fast);
}
.lecon-type--wide {
  grid-column: span 2;
}
.lecon-type img {
  width: 100%;
  border-radius: var(--radius-s);
}
.lecon-type:hover,
.lecon-type--current {
  box-shadow: inset 0 0 0 2px var(--bronze-light);
}
.lecon-type:focus-visible,
.lecon-enlarge:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.lecon-type-copy {
  margin-top: var(--space-3);
  padding: var(--space-3) var(--space-4);
  background: var(--bg-sunken);
  border-left: 3px solid var(--bronze);
}
.lecon-type-copy p {
  margin: 0 0 var(--space-2);
}
.lecon-enlarge {
  min-height: 44px;
  padding: 0 var(--space-4);
  background: none;
  border: 0;
  box-shadow: inset 0 0 0 1px var(--bronze);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  cursor: pointer;
  transition: box-shadow var(--t-fast);
}
.lecon-enlarge:hover {
  box-shadow: inset 0 0 0 1px var(--bronze-light);
}
.lecon-loop {
  margin: var(--space-5) 0;
  padding: var(--space-4) var(--space-5);
  background: var(--bg-sunken);
  border-top: 2px solid var(--blood);
  box-shadow: inset 0 0 0 1px var(--line);
}
.lecon-loop-text {
  margin: 0;
  font-family: var(--font-display);
  font-size: 18px;
  line-height: 1.5;
}
@media (max-width: 767px) {
  .lecon-compare {
    grid-template-columns: 1fr;
  }
  .lecon-stat-value {
    font-size: 48px;
  }
}
@media (prefers-reduced-motion: reduce) {
  .lecon-type,
  .lecon-enlarge {
    transition: none;
  }
}
</style>
