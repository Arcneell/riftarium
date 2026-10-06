import { ref } from "vue"

/* Dernier maillon du fil d'Ariane, fourni par la page affichée (nom de la carte, du
   deck…). La coquille le vide à chaque changement de page. */
export const pageCrumb = ref(null)

export function setPageCrumb(label) {
  pageCrumb.value = label || null
}

export function clearPageCrumb() {
  pageCrumb.value = null
}
