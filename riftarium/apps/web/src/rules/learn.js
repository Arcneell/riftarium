/* Guide d'apprentissage : neuf chapitres courts.
   Vocabulaire aligné sur les règles officielles. Visuels = set Origins (CDN Riot). */

import { CARDS } from "./guide.js"
import { cardThumb } from "../api.js"

const thumb = (card, w = 220) => ({ ...card, img: cardThumb(card.img, w) })

export const LEARN_INTRO =
  "Chaque tour commence par ABCD : éveil, départ, canalisation, pioche. Ensuite, jouez des unités, envoyez-les sur les champs de bataille et tenez ces champs pour marquer, jusqu'à 8 points."

/* Le sigle vient de l'anglais : sans cette phrase, A, B, C, D ne correspondent
   à aucun nom de phase en français. */
export const ABCD_NOTE =
  "ABCD reprend les initiales anglaises des quatre phases du début de tour : Awaken, Beginning, Channel, Draw, soit Éveil, Départ, Canalisation, Pioche."

export const ABCD_PHASES = [
  { letter: "A", name: "Éveil", text: "Préparer runes, unités, équipements." },
  { letter: "B", name: "Départ", text: "Effets de début de tour, puis points d'occupation." },
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
    lead: "Riftbound se gagne en contrôlant des champs de bataille. Il n'y a pas de points de vie à faire tomber : le premier à 8 points l'emporte.",
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
          ["Deck principal", "40+", "Unités, sorts, équipements (dont votre champion élu)"],
          ["Deck de runes", "12", "Ressources"],
          ["Légende", "1", "Identité du deck"],
          ["Champs de bataille", "3", "Objectifs (1 tiré au hasard en duel)"]
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
            text: "Effet ponctuel (dégâts, bonus, réponse), puis la carte part à la défausse."
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
            text: "L'objectif. Chaque champ a son propre effet.",
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
        text: "À 7, conquérir ne donne le 8ᵉ point que si vous avez marqué **sur chaque champ ce tour**. Sinon, vous piochez une carte. L'occupation, elle, n'a pas cette restriction."
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
        text: "**Exténuation** : si vous devez piocher alors que votre deck principal est vide, vous mélangez votre défausse (la pile de vos sorts joués et de vos cartes éliminées ou défaussées) pour en faire un nouveau deck. Un adversaire gagne 1 point, puis vous piochez."
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
          { title: "Runes", text: "Vos 12 runes, face cachée, forment un deck séparé." },
          {
            title: "Légende + champion",
            text: "Légende face visible. Sortez le champion élu du deck et posez-le face visible dans sa zone."
          },
          {
            title: "Champs",
            text: "En duel : chacun tire **au hasard** 1 de ses 3 champs. Les deux vont au centre."
          },
          { title: "Decks", text: "Mélangez le deck principal. Tirez au hasard le premier joueur." },
          {
            title: "Main",
            text: "Piochez 4 cartes. Mulligan (une seule fois) : mettez jusqu'à 2 cartes de côté, piochez-en autant, puis glissez les cartes écartées sous le deck."
          }
        ]
      },
      {
        type: "note",
        kind: "key",
        title: "Règle",
        text: "Le joueur qui commence en second canalise **3 runes** à son premier tour, pour compenser."
      }
    ]
  },
  {
    slug: "tour",
    title: "Le tour de jeu",
    kicker: "La séquence ABCD",
    summary: "Éveil, départ, canalisation, pioche, puis phase principale.",
    ref: "315",
    lead: "Toujours la même séquence. Les quatre premières phases sont automatiques ; ensuite vous jouez.",
    blocks: [
      { type: "abcd" },
      {
        type: "ul",
        items: [
          "**Éveil** : tout ce que vous contrôlez se prépare.",
          "**Départ** : effets de début de tour, puis +1 point par champ que vous contrôlez (occupation).",
          "**Canalisation** : 2 runes (3 au 1ᵉʳ tour du joueur qui commence en second).",
          "**Pioche** : 1 carte. Pas de limite de main.",
          "**Phase principale** : jouez des cartes, déplacez une unité préparée (base ↔ champ), activez des compétences, puis passez."
        ]
      },
      {
        type: "note",
        kind: "warn",
        title: "Attention",
        text: "L'adversaire peut répondre (Réactions) et intervenir en confrontation. Même un champ vide n'est pas acquis tout de suite : vous en prenez le contrôle à la fin de la confrontation."
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
    lead: "Vos 12 runes forment un deck à part. Vous en canalisez 2 chaque tour, automatiquement : vos ressources ne dépendent pas de votre pioche.",
    blocks: [
      {
        type: "compare",
        left: {
          title: "Énergie",
          kicker: "Épuiser",
          text: "La rune est tournée sur le côté. L'énergie n'a pas de domaine.",
          recover: "Revient à votre prochain éveil"
        },
        right: {
          title: "Essence",
          kicker: "Recycler",
          text: "La rune est glissée sous le deck de runes. Elle doit être du domaine demandé.",
          recover: "Revient quand vous la canaliserez à nouveau"
        }
      },
      {
        type: "note",
        kind: "key",
        title: "Règle clé",
        text: "Épuisez d'abord, recyclez ensuite : une rune épuisée peut encore être recyclée pour l'essence. Si vous gardez des runes préparées, vous pourrez payer une Réaction pendant le tour adverse."
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
        headers: ["Vitesse", "Quand la jouer"],
        rows: [
          ["Sans mot-clé", "Pendant votre tour, chaîne vide, hors confrontation"],
          ["Action", "Comme sans mot-clé, et aussi pendant une confrontation, quel que soit le tour"],
          ["Réaction", "Comme Action, et aussi en réponse à un sort déjà dans la chaîne"]
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
    lead: "On ne « déclare » pas d'attaque : on **déplace** une unité préparée sur un champ. S'il y a déjà des unités adverses, une confrontation s'ouvre, puis un combat.",
    blocks: [
      {
        type: "ul",
        items: [
          "Une unité arrive **épuisée** : elle ne pourra se déplacer qu'à votre prochain tour, une fois préparée par l'éveil (sauf **Accélération**).",
          "On se déplace de la base vers un champ, ou l'inverse. Jamais d'un champ à l'autre, sauf avec **Gank**.",
          "**Confrontation** : chacun à son tour joue une Action ou une Réaction, ou passe. Quand les deux joueurs passent l'un après l'autre, elle se termine.",
          "Les dégâts sont infligés **en même temps**. Une unité avec **Tank** doit recevoir des dégâts mortels avant les autres unités de son camp. **Assaut** donne de la puissance en attaque, **Bouclier** en défense.",
          "Si seul l'attaquant garde des unités sur le champ, il en prend le contrôle : **conquête**, +1 point. Si les deux camps ont survécu, les attaquants retournent à leur base."
        ]
      },
      {
        type: "note",
        kind: "warn",
        title: "Attention",
        text: "Un champ vide ouvre aussi une confrontation. Si personne n'intervient, vous en prenez le contrôle à la fin de celle-ci."
      }
    ]
  },
  {
    slug: "chaine",
    title: "La chaîne",
    kicker: "Chacun son tour",
    summary: "Les sorts s'empilent ; dernier entré, premier résolu.",
    ref: "327",
    lead: "Un sort entre dans la **chaîne**. L'adversaire peut répondre. Puis on dépile.",
    blocks: [
      {
        type: "ol",
        items: [
          "Vous jouez un sort : il entre dans la chaîne.",
          "L'adversaire répond avec une Réaction : elle s'empile au-dessus.",
          "Le dernier sort entré se résout en premier.",
          "Puis votre sort se résout, s'il est encore valide."
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
    lead: "Retenez la boucle du tour. Les détails viendront en jouant.",
    blocks: [
      { type: "loop" },
      {
        type: "ol",
        items: [
          "Tour 1 : canalisez, jouez une unité dans votre base (elle arrive épuisée), et gardez si possible une rune préparée pour répondre.",
          "Tour 2 : à l'éveil, votre unité se prépare. Déplacez-la vers un champ de bataille.",
          "Enchaînez conquêtes et occupations jusqu'à 8 points."
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
