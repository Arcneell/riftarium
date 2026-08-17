<script setup>
import { computed, onMounted, ref } from "vue";
import { useRoute, useRouter } from "vue-router";

const route = useRoute();
const router = useRouter();

const documents = ref(null);
const error = ref("");
const doc = ref("core");
const sectionId = ref(null);
const ruleId = ref(null);
const openChapters = ref(new Set());
const searchQuery = ref("");
const searchHits = ref([]);
let searchIndex = [];
let locate = new Map();
let searchTimer = null;

/* --- utilitaires hérités du lecteur Le Codex --- */
const escapeHtml = value => value.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const normalize = value => value.replace(/./gu, char => {
  const folded = char.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return folded.length === char.length ? folded : char.toLowerCase();
});
const bare = number => number.replace(/\.$/, "");

const TOKEN_COLORS = { R: "var(--fury)", G: "var(--calm)", B: "var(--mind)", O: "var(--body)", P: "var(--chaos)", Y: "var(--order)" };

function formatText(text) {
  let html = escapeHtml(text);
  html = html.replace(/\[([A-Z0-9]{1,3})\]/g, (match, token) => {
    const color = TOKEN_COLORS[token] || (/^\d+$/.test(token) ? "var(--muted)" : "var(--gold-deep)");
    return `<span class="rtoken" style="--chip:${color}">${token}</span>`;
  });
  return html.replace(
    /\b(règles?|sections?)\s+(\d{3}(?:\.\d+)*(?:\.[a-z])?(?:\.\d+)*)/gi,
    (match, word, number) => `<button class="rref" data-ref="${bare(number)}">${word} ${number}</button>`
  );
}

/* --- index de recherche et localisation des renvois --- */
function buildIndex() {
  searchIndex = [];
  locate = new Map();
  for (const [docKey, document] of Object.entries(documents.value)) {
    for (const chapter of document.chapters) {
      locate.set(`${docKey}:${bare(chapter.number)}`, { doc: docKey, section: chapter.sections[0]?.id });
      for (const section of chapter.sections) {
        locate.set(`${docKey}:${bare(section.number)}`, { doc: docKey, section: section.id });
        for (const entry of section.entries) {
          locate.set(`${docKey}:${bare(entry.number)}`, { doc: docKey, section: section.id, rule: entry.id });
          searchIndex.push({
            doc: docKey,
            docTitle: document.title,
            section: section.id,
            path: `${chapter.title} › ${section.number} ${section.title}`,
            number: entry.number,
            id: entry.id,
            text: entry.text,
            haystack: normalize(`${entry.number} ${entry.text}`)
          });
        }
      }
    }
  }
}

const currentDoc = computed(() => documents.value?.[doc.value]);
const sections = computed(() =>
  currentDoc.value?.chapters.flatMap(chapter => chapter.sections.map(section => ({ ...section, chapter }))) ?? []
);
const currentSection = computed(() => sections.value.find(section => section.id === sectionId.value));
const sectionIndex = computed(() => sections.value.findIndex(section => section.id === sectionId.value));
const previousSection = computed(() => sections.value[sectionIndex.value - 1]);
const nextSection = computed(() => sections.value[sectionIndex.value + 1]);

function go(docKey, section, rule = null) {
  doc.value = docKey;
  sectionId.value = section ?? sections.value[0]?.id;
  ruleId.value = rule;
  const chapter = currentSection.value?.chapter;
  if (chapter) openChapters.value.add(chapter.id);
  router.replace({ query: { doc: docKey, section: sectionId.value, ...(rule ? { rule } : {}) } });
  if (rule) {
    requestAnimationFrame(() => {
      document.getElementById(`r-${rule}`)?.scrollIntoView({ block: "center", behavior: "smooth" });
    });
  } else {
    window.scrollTo({ top: 0, behavior: "smooth" });
  }
}

function switchDoc(docKey) {
  if (docKey !== doc.value) go(docKey, documents.value[docKey].chapters[0].sections[0].id);
}

function followRef(number) {
  const hit = locate.get(`${doc.value}:${number}`) ?? locate.get(`core:${number}`) ?? locate.get(`tournament:${number}`);
  if (hit) go(hit.doc, hit.section, hit.rule ?? null);
}

function onMainClick(event) {
  const ref = event.target.closest("[data-ref]");
  if (ref) followRef(ref.dataset.ref);
}

/* --- recherche --- */
function snippet(entry, tokens) {
  const folded = normalize(entry.text);
  const first = tokens.map(token => folded.indexOf(token)).filter(pos => pos >= 0).sort((a, b) => a - b)[0] ?? 0;
  const start = Math.max(0, first - 60);
  const slice = entry.text.slice(start, start + 190);
  return (start > 0 ? "… " : "") + slice + (start + 190 < entry.text.length ? " …" : "");
}

function runSearch() {
  const trimmed = searchQuery.value.trim();
  if (trimmed.length < 2) { searchHits.value = []; return; }
  const tokens = normalize(trimmed).split(/\s+/).filter(Boolean);
  searchHits.value = searchIndex
    .filter(entry => tokens.every(token => entry.haystack.includes(token)))
    .slice(0, 40)
    .map(entry => ({ ...entry, snippet: snippet(entry, tokens) }));
}

function onSearchInput() {
  clearTimeout(searchTimer);
  searchTimer = setTimeout(runSearch, 180);
}

function pickHit(hit) {
  searchQuery.value = "";
  searchHits.value = [];
  go(hit.doc, hit.section, hit.id);
}

function toggleChapter(chapterId) {
  openChapters.value.has(chapterId) ? openChapters.value.delete(chapterId) : openChapters.value.add(chapterId);
  openChapters.value = new Set(openChapters.value);
}

onMounted(async () => {
  try {
    const response = await fetch("/data/rules-fr.json");
    documents.value = await response.json();
    buildIndex();
    const q = route.query;
    const docKey = documents.value[q.doc] ? q.doc : "core";
    const wanted = documents.value[docKey].chapters.flatMap(c => c.sections).find(s => s.id === q.section);
    doc.value = docKey;
    sectionId.value = wanted?.id ?? documents.value[docKey].chapters[0].sections[0].id;
    ruleId.value = q.rule ?? null;
    const chapter = documents.value[docKey].chapters.find(c => c.sections.some(s => s.id === sectionId.value));
    if (chapter) openChapters.value.add(chapter.id);
    if (ruleId.value) {
      requestAnimationFrame(() => {
        document.getElementById(`r-${ruleId.value}`)?.scrollIntoView({ block: "center" });
      });
    }
  } catch {
    error.value = "Impossible de charger les règles. Réessayez dans un instant.";
  }
});
</script>

<template>
  <div class="page-banner">
    <div class="wrap">
      <p class="eyebrow">Règles officielles</p>
      <h2>Le texte intégral, consultable et cherchable</h2>
      <p class="lead">Reproduit tel quel depuis les documents officiels de Riot Games. Chaque renvoi est cliquable.</p>
    </div>
  </div>

  <section style="padding-top:36px" v-if="documents">
    <div class="wrap">
      <div class="toolbar">
        <div class="filters" role="tablist" aria-label="Document">
          <button v-for="(d, key) in documents" :key="key" class="filter" role="tab"
                  :aria-pressed="doc === key" @click="switchDoc(key)">
            {{ d.title }}
          </button>
        </div>
        <label class="search" style="position:relative">
          <Icon name="search" :size="18" />
          <input type="search" v-model="searchQuery" @input="onSearchInput"
                    placeholder="Mot-clé ou numéro de règle…" aria-label="Rechercher dans les règles" />
        </label>
      </div>

      <div class="rules-hits panel" v-if="searchHits.length">
        <button class="rules-hit" v-for="hit in searchHits" :key="hit.doc + hit.id" @click="pickHit(hit)">
          <span class="mono" style="color:var(--gold-deep)">{{ hit.number }}</span>
          <span class="muted" style="font-size:.72rem">{{ hit.docTitle }} › {{ hit.path }}</span>
          <span style="font-size:.88rem">{{ hit.snippet }}</span>
        </button>
      </div>
      <p class="muted mono" v-else-if="searchQuery.trim().length >= 2" style="font-size:.8rem; margin-bottom:20px">Aucune règle trouvée.</p>

      <div class="rules-layout">
        <aside class="rules-toc">
          <p class="muted mono" style="font-size:.7rem; margin-bottom:12px">
            {{ currentDoc.subtitle }}<br />Mis à jour le {{ currentDoc.updated }} · {{ currentDoc.ruleCount }} règles<br />
            <a :href="currentDoc.source" target="_blank" rel="noopener">PDF officiel ↗</a>
          </p>
          <div v-for="chapter in currentDoc.chapters" :key="chapter.id" class="toc-chapter">
            <button class="toc-chapter-btn" @click="toggleChapter(chapter.id)"
                    :aria-expanded="openChapters.has(chapter.id)">
              <i>{{ openChapters.has(chapter.id) ? "▾" : "▸" }}</i> {{ chapter.title }}
              <small>{{ chapter.sections.length }}</small>
            </button>
            <div v-if="openChapters.has(chapter.id)">
              <button v-for="section in chapter.sections" :key="section.id" class="toc-section"
                      :aria-current="section.id === sectionId" @click="go(doc, section.id)">
                <b>{{ bare(section.number) }}</b> {{ section.title }}
              </button>
            </div>
          </div>
        </aside>

        <div class="rules-main" @click="onMainClick" v-if="currentSection">
          <p class="muted mono" style="font-size:.72rem">
            {{ currentDoc.title }} › {{ currentSection.chapter.number }} {{ currentSection.chapter.title }}
          </p>
          <h2 style="margin:8px 0 4px">{{ currentSection.title }}</h2>
          <p class="muted" style="font-size:.85rem; margin-bottom:26px">
            Section {{ bare(currentSection.number) }} · {{ currentSection.entries.length }} règles · mise à jour du {{ currentDoc.updated }}
          </p>

          <article v-for="entry in currentSection.entries" :key="entry.id"
                   class="rule" :class="{ target: entry.id === ruleId }" :id="`r-${entry.id}`"
                   :style="{ marginLeft: Math.min(entry.depth, 4) * 22 + 'px' }">
            <span class="rule-num mono">{{ entry.number }}</span>
            <div class="rule-body">
              <p v-html="formatText(entry.text)"></p>
              <div class="rule-example" v-for="(example, i) in entry.examples" :key="i">
                <b>Exemple</b>
                <p v-html="formatText(example.text)"></p>
              </div>
              <div v-if="entry.refs.length" style="display:flex; gap:8px; flex-wrap:wrap; margin-top:10px">
                <button v-for="ref in entry.refs" :key="ref.number" class="rref" :data-ref="bare(ref.number)">
                  → {{ ref.number }} {{ ref.label }}
                </button>
              </div>
            </div>
          </article>

          <div class="rules-nav">
            <button class="btn btn-ghost" :disabled="!previousSection" @click="previousSection && go(doc, previousSection.id)">
              ← {{ previousSection?.title ?? "Début" }}
            </button>
            <button class="btn btn-ghost" :disabled="!nextSection" @click="nextSection && go(doc, nextSection.id)">
              {{ nextSection?.title ?? "Fin" }} →
            </button>
          </div>

          <p class="muted" style="font-size:.76rem; margin-top:30px">
            Texte reproduit depuis le document officiel « {{ currentDoc.title }} » de Riftbound
            (mise à jour du {{ currentDoc.updated }}), publié par Riot Games. En cas de divergence,
            le <a :href="currentDoc.source" target="_blank" rel="noopener">PDF officiel</a> fait foi.
          </p>
        </div>
      </div>
    </div>
  </section>
  <section v-else><div class="wrap"><p :class="error ? 'error' : 'muted'">{{ error || "Chargement des règles…" }}</p></div></section>
</template>
