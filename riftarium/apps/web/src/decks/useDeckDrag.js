import { nextTick, reactive } from "vue"

/* Glisser-déposer façon table de jeu, à la souris seulement : une carte de la galerie
   se dépose sur le panneau du deck pour l'ajouter, une ligne du deck qu'on lâche hors
   du panneau est retirée. Logique pure, sans rendu : le fantôme (.atelier-ghost) et la
   consigne « Déposez ici » sont dessinés par la page et par DeckList à partir de `drag`.

   - enabled      : getter, faux en lecture seule
   - finePointer  : le glisser n'existe qu'avec un pointeur précis
   - reducedMotion: coupe le vol du fantôme vers sa ligne
   - panel        : ref (ou computed) de la racine de DeckList, relue à chaque mouvement
   - onDropAdd(card) -> boolean : ajoute la carte, renvoie vrai si elle l'a été
   - onDropRemove(cardId)       : retire un exemplaire
   - onStart()                  : le glisser démarre (masquer l'aperçu) */
export function useDeckDrag({ enabled, finePointer, reducedMotion, panel, onDropAdd, onDropRemove, onStart }) {
  const drag = reactive({ active: false, card: null, from: "", x: 0, y: 0, overDeck: false })
  let dragStart = null
  let dragMoved = false
  let suppress = false

  function onTilePointerDown(card, from, event) {
    if (!enabled() || !finePointer || event.pointerType === "touch" || event.button !== 0) return
    if (event.target.closest(".decklist-actions")) return
    dragStart = { card, from, x: event.clientX, y: event.clientY }
    dragMoved = false
    window.addEventListener("pointermove", onDragMove)
    window.addEventListener("pointerup", onDragEnd, { once: true })
  }

  function onDragMove(event) {
    if (!dragStart) return
    if (!drag.active) {
      if (Math.hypot(event.clientX - dragStart.x, event.clientY - dragStart.y) < 8) return
      drag.active = true
      drag.card = dragStart.card
      drag.from = dragStart.from
      onStart?.()
      document.body.classList.add("drag-active")
    }
    dragMoved = true
    drag.x = event.clientX
    drag.y = event.clientY
    const rect = panel.value?.getBoundingClientRect()
    drag.overDeck = Boolean(
      rect &&
      event.clientX >= rect.left &&
      event.clientX <= rect.right &&
      event.clientY >= rect.top &&
      event.clientY <= rect.bottom
    )
  }

  async function onDragEnd() {
    window.removeEventListener("pointermove", onDragMove)
    const wasActive = drag.active
    const { card, from, overDeck } = { card: drag.card, from: drag.from, overDeck: drag.overDeck }
    dragStart = null
    document.body.classList.remove("drag-active")
    if (!wasActive) return
    suppress = dragMoved
    setTimeout(() => (suppress = false), 0)
    if (from === "gallery" && overDeck) {
      if (onDropAdd(card)) await flyGhostToRow(card)
    } else if (from === "deck" && !overDeck) {
      onDropRemove(card.id)
    }
    drag.active = false
    drag.card = null
    drag.overDeck = false
  }

  /* Le fantôme glisse jusqu'à sa ligne dans le deck (animation FLIP légère). */
  async function flyGhostToRow(card) {
    if (reducedMotion) return
    await nextTick()
    const ghost = document.querySelector(".atelier-ghost")
    const row = panel.value?.querySelector(`[data-row="${CSS.escape(card.id)}"]`)
    if (!ghost || !row) return
    const target = row.getBoundingClientRect()
    const animation = ghost.animate(
      [
        { transform: `translate(${drag.x - 55}px, ${drag.y - 78}px) rotate(4deg)`, opacity: 1 },
        { transform: `translate(${target.left + 20}px, ${target.top - 10}px) rotate(0deg) scale(0.32)`, opacity: 0.2 }
      ],
      { duration: 260, easing: "cubic-bezier(0.22, 0.8, 0.32, 1)" }
    )
    await animation.finished.catch(() => {})
  }

  /* Vrai juste après un vrai glissement : la page ignore alors le clic qui suit. */
  const suppressClick = () => suppress

  /* `{ once: true }` ne retire l'écouteur qu'après un relâchement : un démontage en
     cours de glissement le laisserait accroché à window. */
  function dispose() {
    window.removeEventListener("pointermove", onDragMove)
    window.removeEventListener("pointerup", onDragEnd)
    document.body.classList.remove("drag-active")
    dragStart = null
  }

  return { drag, onTilePointerDown, suppressClick, dispose }
}
