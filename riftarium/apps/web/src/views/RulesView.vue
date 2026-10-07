<script setup>
import { computed, ref } from "vue"
import { useOnline } from "../composables/useOnline.js"
import OfficialToc from "../rules/OfficialToc.vue"
import RulesHeader from "../rules/RulesHeader.vue"
import { bare, useRulesReader } from "../rules/useRulesReader.js"
import RiftButton from "../ui/RiftButton.vue"
import RiftChoice from "../ui/RiftChoice.vue"
import RiftEmpty from "../ui/RiftEmpty.vue"
import RiftField from "../ui/RiftField.vue"
import RiftSheet from "../ui/RiftSheet.vue"
import RiftSkeleton from "../ui/RiftSkeleton.vue"
import RiftText from "../ui/RiftText.vue"

const online = useOnline()
const {
  documents,
  error,
  load,
  breakpoint,
  doc,
  sectionId,
  ruleId,
  openChapters,
  currentDoc,
  currentSection,
  previousSection,
  nextSection,
  searchQuery,
  searchHits,
  onSearchInput,
  clearSearch,
  go,
  switchDoc,
  followRef,
  pickHit,
  toggleChapter
} = useRulesReader()

const crumbs = [{ label: "Règles", to: "/regles" }, { label: "Texte officiel" }]

const docOptions = computed(() =>
  Object.entries(documents.value ?? {}).map(([value, document]) => ({ value, label: document.title }))
)
const compact = computed(() => breakpoint.value !== "desktop")
const tocOpen = ref(false)

function pickSection(id) {
  tocOpen.value = false
  go(doc.value, id)
}

/* Clic délégué : renvois de `RiftText refs` et boutons des `entry.refs`. */
function onTextClick(event) {
  const target = event.target.closest?.("[data-ref]")
  if (target) followRef(target.dataset.ref)
}
</script>

<template>
  <div class="wrap cards-wrap regles-officiel">
    <RulesHeader title="Règles officielles" kicker="Texte intégral" :crumbs="crumbs">
      <template v-if="documents">
        <RiftChoice :model-value="doc" :options="docOptions" label="Document" @update:model-value="switchDoc" />
        <p class="officiel-meta">
          Mis à jour le {{ currentDoc.updated }} · {{ currentDoc.ruleCount }} règles ·
          <a :href="currentDoc.source" target="_blank" rel="noopener">PDF officiel ↗</a>
        </p>
      </template>
    </RulesHeader>

    <p v-if="!online" class="officiel-offline" role="status">Hors ligne — règles servies depuis le cache</p>

    <RiftEmpty v-if="error" title="Règles indisponibles" :text="error">
      <RiftButton variant="secondary" @click="load">Réessayer</RiftButton>
    </RiftEmpty>

    <div v-else-if="!documents" class="officiel-loading">
      <RiftSkeleton :lines="6" />
    </div>

    <template v-else>
      <div class="officiel-search" @keydown.esc="clearSearch">
        <RiftField
          v-model="searchQuery"
          search
          hide-label
          label="Rechercher dans les règles"
          placeholder="Mot-clé ou numéro de règle…"
          enterkeyhint="search"
          inputmode="search"
          autocapitalize="off"
          autocorrect="off"
          spellcheck="false"
          @input="onSearchInput"
        />
        <div v-if="searchHits.length" class="officiel-hits">
          <button
            v-for="hit in searchHits"
            :key="hit.doc + hit.id"
            type="button"
            class="officiel-hit"
            @click="pickHit(hit)"
          >
            <span class="officiel-hit-num">{{ hit.number }}</span>
            <span class="officiel-hit-path">{{ hit.docTitle }} › {{ hit.path }}</span>
            <span class="officiel-hit-text">{{ hit.snippet }}</span>
          </button>
        </div>
        <p v-else-if="searchQuery.trim().length >= 2" class="officiel-nohit">
          Aucune règle trouvée — essayez un autre mot-clé, ou un numéro comme 002.
        </p>
      </div>

      <div class="officiel-layout">
        <aside v-if="!compact" class="officiel-toc">
          <OfficialToc
            :doc="currentDoc"
            :section-id="sectionId"
            :open-chapters="openChapters"
            @pick="pickSection"
            @toggle="toggleChapter"
          />
        </aside>
        <div v-else class="officiel-toc-bar">
          <RiftButton variant="secondary" block aria-haspopup="dialog" @click="tocOpen = true">Sommaire</RiftButton>
        </div>

        <div v-if="currentSection" class="officiel-text" @click="onTextClick">
          <p class="officiel-path">
            {{ currentDoc.title }} › {{ currentSection.chapter.number }} {{ currentSection.chapter.title }}
          </p>
          <h2 class="officiel-title">{{ currentSection.title }}</h2>
          <p class="officiel-sub">
            Section {{ bare(currentSection.number) }} · {{ currentSection.entries.length }} règles
          </p>

          <article
            v-for="entry in currentSection.entries"
            :id="`r-${entry.id}`"
            :key="entry.id"
            class="officiel-rule"
            :class="{ 'officiel-rule--target': entry.id === ruleId }"
            :style="{ '--indent': Math.min(entry.depth, 4) }"
          >
            <span class="officiel-rule-num">{{ entry.number }}</span>
            <div class="officiel-rule-body">
              <RiftText :text="entry.text" tag="p" rules refs />
              <div v-for="(example, i) in entry.examples" :key="i" class="officiel-example">
                <b>Exemple</b>
                <RiftText :text="example.text" tag="p" rules refs />
              </div>
              <div v-if="entry.refs?.length" class="officiel-xrefs">
                <button
                  v-for="reference in entry.refs"
                  :key="reference.number"
                  type="button"
                  class="rift-ref officiel-xref"
                  :data-ref="bare(reference.number)"
                >
                  → {{ reference.number }} {{ reference.label }}
                </button>
              </div>
            </div>
          </article>

          <div class="officiel-nav">
            <RiftButton
              variant="ghost"
              :disabled="!previousSection"
              @click="previousSection && go(doc, previousSection.id)"
            >
              ← {{ previousSection?.title ?? "Début" }}
            </RiftButton>
            <RiftButton variant="ghost" :disabled="!nextSection" @click="nextSection && go(doc, nextSection.id)">
              {{ nextSection?.title ?? "Fin" }} →
            </RiftButton>
          </div>

          <p class="officiel-source">
            Texte reproduit depuis le document officiel « {{ currentDoc.title }} » de Riftbound (mise à jour du
            {{ currentDoc.updated }}), publié par Riot Games. En cas de divergence, le
            <a :href="currentDoc.source" target="_blank" rel="noopener">PDF officiel</a> fait foi.
          </p>
        </div>
      </div>
    </template>

    <RiftSheet v-if="compact && tocOpen" title="Sommaire" @close="tocOpen = false">
      <OfficialToc
        :doc="currentDoc"
        :section-id="sectionId"
        :open-chapters="openChapters"
        @pick="pickSection"
        @toggle="toggleChapter"
      />
    </RiftSheet>
  </div>
</template>

<style scoped>
.regles-officiel {
  padding-bottom: var(--space-7);
}
.officiel-meta {
  margin: var(--space-3) 0 0;
  color: var(--ink-muted);
  font-size: 14px;
}
.officiel-meta a,
.officiel-source a {
  color: var(--bronze-light);
}
.officiel-meta a:focus-visible,
.officiel-source a:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.officiel-offline {
  margin: 0 0 var(--space-4);
  padding: var(--space-2) var(--space-3);
  border: 1px solid var(--line);
  background: var(--bg-sunken);
  color: var(--ink-muted);
  font-size: 14px;
}
.officiel-loading {
  max-width: 640px;
}

/* Recherche collante en haut ; le panneau de résultats se pose dessous. */
.officiel-search {
  position: sticky;
  top: var(--topbar-h);
  z-index: 5;
  margin-bottom: var(--space-4);
  padding: var(--space-2) 0;
  background: var(--bg);
}
.officiel-hits {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  max-height: 60vh;
  overflow-y: auto;
  overscroll-behavior: contain;
  border: 1px solid var(--line);
  background: var(--bg-raised);
  box-shadow: var(--shadow-deep);
}
.officiel-hit {
  display: grid;
  gap: var(--space-1);
  width: 100%;
  min-height: 44px;
  padding: var(--space-3);
  border: 0;
  border-bottom: 1px solid var(--line);
  border-radius: 0;
  background: none;
  box-shadow: none;
  color: var(--ink);
  text-align: left;
  cursor: pointer;
  transition: background var(--t-fast);
}
.officiel-hit:hover {
  background: var(--bg-sunken);
}
.officiel-hit:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: -2px;
}
.officiel-hit-num {
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 18px;
  font-weight: 600;
  letter-spacing: 0.04em;
}
.officiel-hit-path {
  color: var(--ink-muted);
  font-size: 12px;
}
.officiel-hit-text {
  font-size: 14px;
  line-height: 1.45;
}
.officiel-nohit {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  margin: 0;
  padding: var(--space-3);
  border: 1px solid var(--line);
  background: var(--bg-raised);
  color: var(--ink-muted);
  font-size: 14px;
}

/* Mise en page : table des matières collante à gauche dès 1 024 px. */
.officiel-layout {
  display: grid;
  grid-template-columns: minmax(0, 1fr);
  gap: var(--space-5);
  align-items: start;
}
.officiel-toc-bar {
  position: sticky;
  top: calc(var(--topbar-h) + 64px);
  z-index: 4;
  padding: var(--space-1) 0;
  background: var(--bg);
}
@media (min-width: 1024px) {
  .officiel-layout {
    grid-template-columns: 280px minmax(0, 1fr);
    gap: var(--space-6);
  }
  .officiel-toc {
    position: sticky;
    top: calc(var(--topbar-h) + 64px);
    max-height: calc(100dvh - var(--topbar-h) - 80px);
    overflow-y: auto;
    overscroll-behavior: contain;
    border: 1px solid var(--line);
    background: var(--bg-sunken);
  }
}

.officiel-text {
  min-width: 0;
  scroll-margin-top: calc(var(--topbar-h) + 120px);
}
.officiel-path {
  margin: 0;
  color: var(--ink-muted);
  font-family: var(--font-label);
  font-size: 14px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
/* main.css style `h2` : on neutralise localement. */
.officiel-title {
  margin: var(--space-2) 0 var(--space-1);
  padding: 0;
  background: none;
  color: var(--ink);
  font-family: var(--font-display);
  font-size: 26px;
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: 0;
  text-transform: none;
}
.officiel-sub {
  margin: 0 0 var(--space-5);
  color: var(--ink-muted);
  font-size: 14px;
}
.officiel-rule {
  display: grid;
  grid-template-columns: 64px minmax(0, 1fr);
  gap: var(--space-3);
  margin-left: calc(var(--indent, 0) * var(--space-4));
  padding: var(--space-2) var(--space-3);
  border-left: 3px solid transparent;
  scroll-margin-top: calc(var(--topbar-h) + 140px);
}
.officiel-rule--target {
  border-left-color: var(--blood);
  background: var(--bg-raised);
}
.officiel-rule-num {
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 17px;
  font-weight: 600;
  letter-spacing: 0.04em;
}
.officiel-rule-body p {
  margin: 0;
  line-height: 1.6;
}
.officiel-example {
  margin-top: var(--space-3);
  padding: var(--space-3);
  background: var(--bg-sunken);
  font-size: 14px;
}
.officiel-example b {
  display: block;
  margin-bottom: var(--space-1);
  color: var(--bronze-light);
  font-family: var(--font-label);
  font-size: 13px;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}
.officiel-xrefs {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-top: var(--space-3);
}
.officiel-xref {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  padding: 0 var(--space-3);
  border: 1px solid var(--line);
  border-radius: 0;
  background: var(--bg-sunken);
  color: var(--bronze-light);
  font: inherit;
  font-size: 14px;
  cursor: pointer;
  transition: border-color var(--t-fast);
}
.officiel-xref:hover {
  border-color: var(--bronze);
}
.officiel-xref:focus-visible {
  outline: 2px solid var(--bronze-light);
  outline-offset: 2px;
}
.officiel-nav {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--space-3);
  margin-top: var(--space-6);
}
.officiel-source {
  margin: var(--space-5) 0 0;
  color: var(--ink-muted);
  font-size: 13px;
}

@media (max-width: 560px) {
  .officiel-rule {
    grid-template-columns: minmax(0, 1fr);
    gap: var(--space-1);
  }
}
@media (prefers-reduced-motion: reduce) {
  .officiel-hit,
  .officiel-xref {
    transition: none;
  }
}
</style>
