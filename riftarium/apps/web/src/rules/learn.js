/* Guide d'apprentissage : neuf chapitres courts.
   Vocabulaire aligné sur les règles officielles. Visuels = set Origins (CDN Riot). */

import { CARDS } from "./guide.js"
import { cardThumb } from "../api.js"

const thumb = (card, w = 220) => ({ ...card, img: cardThumb(card.img, w) })

export const LEARN_INTRO = "ABCD → jouer des unités → les envoyer sur les champs → les tenir → 8 points."

export const ABCD_PHASES = [
  { letter: "A", name: "Éveil", text: "Préparer runes, unités, équipements." },
  { letter: "B", name: "Départ", text: "Effets de début de tour, puis occupation." },
  { letter: "C", name: "Canalisation", text: "2 runes vers votre zone." },
  { letter: "D", name: "Pioche", text: "1 carte du deck principal." },
  { letter: "→", name: "Phase principale", text: "Jouer, déplacer, combattre, passer." }
]

export const CHAPTERS = [
  {
    slug: "apercu",
    title: "Vue d'ensemble",
    kicker: "Par où commencer",
    summary: "Le but du jeu, le matériel, et la boucle d'un tour.",
    ref: "101",
    lead: "Riftbound se gagne en contrôlant des champs de bataille — pas en éliminant l'adversaire. Premier à 8 points.",
    blocks: [
      {
        type: "stat",
        value: "8",
        label: "Points pour gagner",
        text: "Conquérir un champ : +1. Le tenir encore au début de votre tour (occupation) : +1."
      },
      { type: "h", text: "Ce que chacun apporte" },
      {
        type: "table",
        headers: ["Élément", "Taille", "Rôle"],
        rows: [
          ["Deck principal", "40+", "Unités, sorts, équipements"],
          ["Deck de runes", "12", "Ressources"],
          ["Légende", "1", "Identité du deck"]
        ]
      },
      {
        type: "note",
        kind: "key",
        title: "Règle clé",
        text: "Toutes vos cartes doivent correspondre aux domaines de votre légende."
      },
      { type: "h", text: "Types de cartes" },
      {
        type: "types",
        items: [
          {
            key: "legend",
            card: thumb(CARDS.legend),
            title: "Légende",
            text: "Identité et compétence permanente."
          },
          {
            key: "unit",
            card: thumb(CARDS.demolitionist),
            title: "Unité",
            text: "Combat sur les champs. Sa **puissance** décide."
          },
          {
            key: "spell",
            card: thumb(CARDS.spell),
            title: "Sort",
            text: "Effet unique : dégâts, bonus, réponse."
          },
          {
            key: "gear",
            card: thumb(CARDS.gear),
            title: "Équipement",
            text: "Permanent : bonus ou compétence."
          },
          {
            key: "bf",
            card: thumb(CARDS.bfYou, 320),
            title: "Champ",
            text: "L'objectif. Chaque champ a un effet unique.",
            wide: true
          },
          {
            key: "rune",
            card: thumb(CARDS.furyRune),
            title: "Rune",
            text: "Ressource : **épuiser** = énergie, **recycler** = essence."
          }
        ]
      },
      { type: "h", text: "Un tour" },
      { type: "abcd" },
      { type: "loop" }
    ]
  },
  {
    slug: "victoire",
    title: "Comment gagner",
    kicker: "La course à 8",
    summary: "Conquête, occupation, et le piège du dernier point.",
    ref: "193",
    lead: "Premier à 8 points **en étant strictement devant**. Une égalité à 8 ne suffit pas.",
    blocks: [
      {
        type: "table",
        headers: ["Source", "Quand", "Pts"],
        rows: [
          ["Conquête", "Vous prenez le contrôle d'un champ", "+1"],
          ["Occupation", "Vous le tenez encore au début de votre tour", "+1"],
          ["Effets", "Certains textes donnent des points", "var."]
        ]
      },
      {
        type: "note",
        kind: "key",
        title: "Dernier point",
        text: "À 7, conquérir ne donne le 8ᵉ point que si vous avez marqué **sur chaque champ ce tour**. Sinon vous piochez. L'occupation, elle, n'a pas cette restriction."
      },
      {
        type: "table",
        headers: ["À 7 points", "Résultat"],
        rows: [
          ["Occuper un champ tenu", "Victoire"],
          ["Marquer sur chaque champ ce tour", "Victoire"],
          ["Conquérir un seul champ", "Vous piochez"]
        ]
      },
      {
        type: "p",
        text: "**Exténuation** : piocher deck vide → défausse remélangée, adversaire +1 point, puis vous piochez."
      }
    ]
  },
  {
    slug: "mise-en-place",
    title: "Mise en place",
    kicker: "Avant le premier tour",
    summary: "Matériel, table, main de départ.",
    ref: "107",
    lead: "Posez d'abord les piles, puis piochez. Les deux joueurs font chaque étape ensemble.",
    blocks: [
      {
        type: "steps",
        items: [
          { title: "Runes", text: "12 runes face cachée, deck séparé." },
          { title: "Légende + champion", text: "Légende visible. Champion élu sorti du deck, visible." },
          {
            title: "Champs",
            text: "En duel : chacun tire **au hasard** 1 de ses 3 champs. Les deux vont au centre."
          },
          { title: "Decks", text: "Mélanger le principal. Tirer le premier joueur." },
          {
            title: "Main",
            text: "Piocher 4. Mulligan unique : jusqu'à 2 cartes recyclées sous le deck."
          }
        ]
      },
      {
        type: "note",
        kind: "tip",
        title: "Astuce",
        text: "Le second joueur canalise **3 runes** à son premier tour (compensation)."
      }
    ]
  },
  {
    slug: "tour",
    title: "Le tour de jeu",
    kicker: "La séquence ABCD",
    summary: "Éveil → départ → canalisation → pioche → phase principale.",
    ref: "315",
    lead: "Toujours la même séquence. Les quatre premières phases sont automatiques ; ensuite vous jouez.",
    blocks: [
      { type: "abcd" },
      {
        type: "ul",
        items: [
          "**Éveil** — tout ce que vous contrôlez se prépare.",
          "**Départ** — effets, puis +1 par champ occupé.",
          "**Canalisation** — 2 runes (3 au 1ᵉʳ tour du second joueur).",
          "**Pioche** — 1 carte. Pas de limite de main.",
          "**Phase principale** — jouer, déplacer une unité préparée (base ↔ champ), activer, passer."
        ]
      },
      {
        type: "note",
        kind: "warn",
        title: "Attention",
        text: "L'adversaire peut répondre (Réactions) et intervenir en confrontation. Un champ vide n'est pas acquis tant que la phase n'est pas finie."
      },
      { type: "loop" }
    ]
  },
  {
    slug: "runes",
    title: "Énergie et essence",
    kicker: "Comment on paie",
    summary: "Épuiser pour l'énergie, recycler pour l'essence.",
    ref: "160",
    lead: "12 runes, deck séparé. 2 par tour, automatiquement — pas de famine.",
    blocks: [
      {
        type: "compare",
        left: {
          title: "Énergie",
          kicker: "Épuiser",
          text: "Rune tournée. Sans domaine. Revient à l'éveil suivant.",
          recover: "Faible risque"
        },
        right: {
          title: "Essence",
          kicker: "Recycler",
          text: "Rune sous le deck. Le domaine doit matcher. Tempo perdu.",
          recover: "Risque élevé"
        }
      },
      {
        type: "note",
        kind: "key",
        title: "Règle clé",
        text: "Épuisez d'abord, recyclez ensuite : une rune épuisée peut encore payer l'essence. Garder des runes ouvertes menace une réponse."
      },
      { type: "h", text: "Essayez" },
      {
        type: "p",
        text: "Objectif : 2 énergie (Rearguard) + 1 essence Fureur (Seal of Rage)."
      },
      { type: "runes" }
    ]
  },
  {
    slug: "vitesses",
    title: "Actions et réactions",
    kicker: "Quand jouer",
    summary: "Sans mot-clé, Action, Réaction.",
    ref: "153",
    lead: "La vitesse d'un sort dit **quand** vous avez le droit de le jouer.",
    blocks: [
      {
        type: "table",
        headers: ["Vitesse", "Quand", "Réponse ?"],
        rows: [
          ["Sans mot-clé", "Votre phase, chaîne vide", "Réaction"],
          ["Action", "+ confrontations ouvertes", "Réaction"],
          ["Réaction", "+ répondre dans la chaîne", "Réaction"]
        ]
      },
      {
        type: "note",
        kind: "key",
        title: "Règle clé",
        text: "Répondre à un sort déjà dans la chaîne exige [Réaction]. Une Action ne suffit pas."
      }
    ]
  },
  {
    slug: "combat",
    title: "Confrontations et combat",
    kicker: "Prendre un champ",
    summary: "Déplacer, contester, sorts, dégâts.",
    ref: "464",
    lead: "On ne « déclare » pas d'attaque : on **déplace** une unité préparée sur un champ. S'il y a déjà quelqu'un → confrontation, puis combat.",
    blocks: [
      {
        type: "ul",
        items: [
          "Une unité arrive **épuisée** : elle bouge à votre prochain éveil.",
          "Base ↔ champ seulement (sauf **Gank**).",
          "**Confrontation** : Action / Réaction à tour de rôle. Deux passes = fin.",
          "Dégâts **simultanés**. **Tank** = prioritaire. **Assaut** / **Bouclier** = +puissance.",
          "Seul camp restant → **conquête** +1. Les deux survivent → attaquants rappelés."
        ]
      },
      {
        type: "note",
        kind: "warn",
        title: "Attention",
        text: "Un champ vide ouvre aussi une confrontation. Si personne n'intervient, vous prenez le contrôle."
      }
    ]
  },
  {
    slug: "chaine",
    title: "La chaîne",
    kicker: "Rien n'est instantané",
    summary: "Les sorts s'empilent ; dernier entré, premier résolu.",
    ref: "327",
    lead: "Un sort entre dans la **chaîne**. L'adversaire peut répondre. Puis on dépile.",
    blocks: [
      {
        type: "ol",
        items: [
          "Vous jouez → le sort entre dans la chaîne.",
          "Réaction adverse → elle s'empile au-dessus.",
          "Dernier entré se résout en premier.",
          "Puis votre sort — s'il est encore valide."
        ]
      },
      {
        type: "note",
        kind: "key",
        title: "Règle clé",
        text: "Payer les coûts (épuiser / recycler) n'utilise pas la chaîne. On réagit à la carte, pas au paiement."
      }
    ]
  },
  {
    slug: "assembler",
    title: "Tout assembler",
    kicker: "Première partie",
    summary: "La boucle, puis le plateau animé.",
    ref: "301",
    lead: "Retenez la boucle. Le reste s'apprend en jouant.",
    blocks: [
      { type: "loop" },
      {
        type: "ol",
        items: [
          "Tour 1 : canaliser, jouer une unité en base (épuisée), garder une rune si possible.",
          "Tour 2 : éveil → l'unité se prépare → premier déplacement vers un champ.",
          "Enchaînez occupation et conquête jusqu'à 8."
        ]
      },
      {
        type: "note",
        kind: "tip",
        title: "La suite",
        text: "Le plateau rejoue une partie carte par carte. L'aide avancée détaille chaque mécanique. Le texte officiel tranche les doutes."
      }
    ]
  }
]

export const DEFAULT_CHAPTER = CHAPTERS[0].slug

export function chapterBySlug(slug) {
  if (!slug) return CHAPTERS[0]
  return CHAPTERS.find((chapter) => chapter.slug === slug) ?? null
}

export function chapterPath(slug) {
  return !slug || slug === DEFAULT_CHAPTER ? "/regles/debutant" : `/regles/debutant/${slug}`
}

export function chapterIndex(slug) {
  const found = CHAPTERS.findIndex((chapter) => chapter.slug === slug)
  return found < 0 ? 0 : found
}
