<script setup>
import { computed, onBeforeUnmount, ref, watch } from "vue"
import { useRouter } from "vue-router"
import { MIN_QUERY, normalize, runSearch } from "../search/search.js"
import RiftField from "../ui/RiftField.vue"
import { useDialog } from "../ui/useDialog.js"

/* Palette de recherche universelle (Ctrl K, « / »). Un combobox : le focus reste
   dans le champ, ↑ ↓ déplacent la sélection, Entrée ouvre, Échap ferme. */
const emit = defineEmits(["close"])
const router = useRouter()

const panel = ref(null)
const query = ref("")
const groups = ref([])
const loading = ref(false)
const searched = ref(false)
const activeIndex = ref(0)
useDialog(panel, () => emit("close"))

const flat = computed(() => groups.value.flatMap((group) => group.items))
const indexOf = (item) => flat.value.indexOf(item)

let timer = null
let controller = null

watch(query, (value) => {
  clearTimeout(timer)
  controller?.abort()
  controller = null
  if (normalize(value).length < MIN_QUERY) {
    groups.value = []
    loading.value = false
    searched.value = false
    return
  }
  loading.value = true
  timer = setTimeout(async () => {
    const current = new AbortController()
    controller = current
    const result = await runSearch(value, { signal: current.signal })
    /* Une frappe plus récente a remplacé cette requête : sa réponse est périmée. */
    if (controller !== current) return
    groups.value = result
    activeIndex.value = 0
    loading.value = false
    searched.value = true
  }, 200)
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  controller?.abort()
})

function move(delta) {
  const count = flat.value.length
  if (!count) return
  activeIndex.value = (activeIndex.value + delta + count) % count
}

function open(item) {
  emit("close")
  router.push(item.to)
}

function onKeydown(event) {
  if (event.key === "ArrowDown") {
    event.preventDefault()
    move(1)
  } else if (event.key === "ArrowUp") {
    event.preventDefault()
    move(-1)
  } else if (event.key === "Enter") {
    const item = flat.value[activeIndex.value]
    if (item) {
      event.preventDefault()
      open(item)
    }
  }
}
</script>

<template>
  <Teleport to="body">
    <div class="palette-overlay" @click.self="emit('close')">
      <div ref="panel" class="palette" role="dialog" aria-modal="true" aria-label="Recherche" tabindex="-1">
        <RiftField
          v-model="query"
          search
          hide-label
          label="Rechercher une carte, un deck, une règle"
          placeholder="Une carte, un deck, une règle…"
          role="combobox"
          aria-autocomplete="list"
          aria-controls="palette-results"
          :aria-expanded="flat.length > 0 ? 'true' : 'false'"
          :aria-activedescendant="flat.length ? `palette-opt-${activeIndex}` : undefined"
          autocomplete="off"
          @keydown="onKeydown"
        />
        <div class="palette-results">
          <p v-if="loading" class="palette-state" role="status">Recherche…</p>
          <p v-else-if="searched && !groups.length" class="palette-state" role="status">
            Aucun résultat pour « {{ query.trim() }} ».
          </p>
          <ul id="palette-results" role="listbox" aria-label="Résultats">
            <template v-for="group in groups" :key="group.key">
              <li class="palette-group" role="presentation">{{ group.label }}</li>
              <li v-if="group.error" class="palette-error" role="presentation">
                Recherche indisponible pour le moment.
              </li>
              <li
                v-for="item in group.items"
                :id="`palette-opt-${indexOf(item)}`"
                :key="item.id"
                role="option"
                class="palette-option"
                :class="{ active: indexOf(item) === activeIndex }"
                :aria-selected="indexOf(item) === activeIndex"
                @mouseenter="activeIndex = indexOf(item)"
                @click="open(item)"
              >
                <img v-if="item.image" :src="item.image" alt="" class="palette-thumb" loading="lazy" />
                <span class="palette-label">{{ item.label }}</span>
                <span class="palette-hint">{{ item.hint }}</span>
              </li>
            </template>
          </ul>
        </div>
        <p class="palette-help" aria-hidden="true">↑ ↓ pour choisir · Entrée pour ouvrir · Échap pour fermer</p>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.palette-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--z-overlay);
  display: flex;
  justify-content: center;
  align-items: flex-start;
  padding: 12vh var(--space-4) var(--space-4);
  background: rgba(5, 4, 4, 0.78);
}
.palette {
  width: min(640px, 100%);
  max-height: 72vh;
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  padding: var(--space-4);
  background: var(--bg-raised);
  border-top: 2px solid var(--blood);
  box-shadow:
    inset 0 0 0 1px var(--line),
    var(--shadow-deep);
}
.palette:focus {
  outline: none;
}
.palette-results {
  overflow-y: auto;
}
.palette-results ul {
  list-style: none;
}
.palette-state,
.palette-error {
  padding: var(--space-2) var(--space-1);
  color: var(--ink-muted);
  font-size: 14px;
}
.palette-group {
  padding: var(--space-3) var(--space-1) var(--space-1);
  font-family: var(--font-label);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.16em;
  text-transform: uppercase;
  color: var(--blood-text);
}
.palette-option {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  padding: var(--space-1) var(--space-2);
  cursor: pointer;
}
.palette-option.active {
  background: rgba(179, 38, 43, 0.25);
  box-shadow: inset 3px 0 0 var(--blood-bright);
}
.palette-thumb {
  width: 28px;
  border-radius: 2px;
}
.palette-label {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.palette-hint {
  font-family: var(--font-label);
  font-size: 12px;
  letter-spacing: 0.08em;
  color: var(--ink-muted);
}
.palette-help {
  font-size: 12px;
  color: var(--ink-muted);
}
@media (max-width: 767px) {
  .palette-overlay {
    padding: 0;
  }
  .palette {
    max-height: none;
    height: 100dvh;
  }
  .palette-help {
    display: none;
  }
}
</style>
