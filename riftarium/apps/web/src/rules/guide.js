/* Guide du débutant : une vraie table de Riftbound en mode 1c1 (duel).
   Cartes réelles du set Origins, visuels servis par le CDN officiel Riot.
   Contenu conforme aux règles officielles (numéros de règle dans `ref`). */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live"
const img = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=360&accountingTag=RB`
const imgWide = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=560&accountingTag=RB`

/* Les cartes utilisées pour la démonstration (deck Yasuo / Calme contre Noxus / Fureur). */
export const CARDS = {
  legend: {
    id: "ogn-259-298",
    name: "Yasuo - Unforgiven",
    kind: "Légende de champion",
    img: img("68e4d3230b785738ae9d86f780f7f5607ef11807-744x1040.png")
  },
  chosen: {
    id: "ogn-205-298",
    name: "Yasuo - Windrider",
    kind: "Champion élu · unité",
    might: 4,
    img: img("f5ba378ce4dad16d17e001814e091d5f484f2681-744x1039.png")
  },
  poro: {
    id: "ogn-052-298",
    name: "Stalwart Poro",
    kind: "Unité",
    might: 2,
    img: img("c4a5d7178e783c3975749271b6df333a82a2328a-744x1039.png")
  },
  guardian: {
    id: "ogn-054-298",
    name: "Sunlit Guardian",
    kind: "Unité",
    might: 3,
    img: img("28bce7a662b9008f65565300f828d98790a641e1-744x1039.png")
  },
  spell: {
    id: "ogn-045-298",
    name: "Defy",
    kind: "Sort",
    img: img("4989bfcc4bd7be77051f0c2c349a981ba9c273e0-744x1039.png")
  },
  gear: {
    id: "ogn-063-298",
    name: "Spirit's Refuge",
    kind: "Équipement",
    img: img("26d5e54580d1f17ed6c35a66ac6a90ce56c99ec8-744x1039.png")
  },
  rune: {
    id: "ogn-042-298",
    name: "Calm Rune",
    kind: "Rune de calme",
    img: img("0a0e8c3d16c2595e2f8efcc2b1466226539b506c-744x1039.png")
  },
  bfYou: {
    id: "ogn-282-298",
    name: "Monastery of Hirana",
    kind: "Champ de bataille",
    img: imgWide("8767d9ed30e2873d3fa1045f973be229da56175d-1038x744.png")
  },
  bfFoe: {
    id: "ogn-279-298",
    name: "Fortified Position",
    kind: "Champ de bataille",
    img: imgWide("45363bbd907f4f3717868cb04b3cfed814b3bb32-1038x744.png")
  },
  foe1: {
    id: "ogn-010-298",
    name: "Legion Rearguard",
    kind: "Unité adverse",
    might: 2,
    img: img("aedece01c7792c689050460db1670e6b9b15b61f-744x1039.png")
  },
  foe2: {
    id: "ogn-012-298",
    name: "Noxus Hopeful",
    kind: "Unité adverse",
    might: 4,
    img: img("c3bb6f4cb58feeb50e396d12ec9865c5434025af-744x1039.png")
  }
}

/* Emplacements sur la table, en % du plateau (translate(-50%,-50%) appliqué). */
export const SPOTS = {
  bfFoe: { x: 32, y: 42 },
  bfYou: { x: 68, y: 42 },
  legend: { x: 7, y: 83 },
  championZone: { x: 19, y: 83 },
  discard: { x: 73.5, y: 83 },
  mainDeck: { x: 84, y: 83 },
  runeDeck: { x: 94.5, y: 83 },
  foeBaseL: { x: 41, y: 12 },
  foeBaseR: { x: 50, y: 12 },
  youBaseL: { x: 41, y: 66 },
  youBaseM: { x: 50, y: 66 },
  youBaseR: { x: 59, y: 66 },
  runeA: { x: 31, y: 83 },
  runeB: { x: 39.5, y: 83 },
  onBfYouA: { x: 61, y: 53 },
  onBfYouB: { x: 75, y: 53 },
  onBfYouFoe: { x: 68, y: 30 },
  spellPlayed: { x: 50, y: 44 },
  showcase: { x: 50, y: 40 }
}

const fan = (index, count, y = 40, spread = 11) => ({
  x: 50 + (index - (count - 1) / 2) * spread,
  y,
  r: (index - (count - 1) / 2) * 4
})

/* Base commune : zones du bas toujours en place une fois la partie installée. */
const table = (extra = []) => [
  { key: "legend", card: CARDS.legend, spot: SPOTS.legend, label: "Zone de légende" },
  { key: "chosen", card: CARDS.chosen, spot: SPOTS.championZone, label: "Zone de champion" },
  { key: "mainDeck", card: CARDS.spell, spot: SPOTS.mainDeck, facedown: true, label: "Deck principal" },
  { key: "runeDeck", card: CARDS.rune, spot: SPOTS.runeDeck, facedown: true, label: "Deck de runes" },
  ...extra
]

export const STEPS = [
  {
    key: "materiel",
    title: "Le matériel",
    ref: "101",
    terms: ["deck principal", "deck de runes", "légende de champion", "champion élu"],
    text: [
      "Un **deck principal** d'au moins 40 cartes : votre **champion élu**, des unités, des sorts et des équipements — 3 exemplaires maximum d'un même nom.",
      "Un **deck de runes** d'exactement **12 runes**, une **légende de champion** qui fixe l'identité de domaine du deck, et **3 champs de bataille**.",
      "Ici : un deck Yasuo, domaine Calme. Toutes les cartes montrées sont de vraies cartes du set Origins."
    ],
    scene: {
      cards: [
        { key: "legend", card: CARDS.legend, spot: fan(0, 7), glow: true },
        { key: "chosen", card: CARDS.chosen, spot: fan(1, 7) },
        { key: "poro", card: CARDS.poro, spot: fan(2, 7) },
        { key: "spell", card: CARDS.spell, spot: fan(3, 7) },
        { key: "gear", card: CARDS.gear, spot: fan(4, 7) },
        { key: "rune", card: CARDS.rune, spot: fan(5, 7) },
        { key: "bfCard", card: CARDS.bfYou, spot: fan(6, 7), wide: true }
      ],
      hideBattlefields: true,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "mise-en-place",
    title: "La mise en place",
    ref: "110",
    terms: ["zone de légende", "zone de champion", "mulligan"],
    text: [
      "Chaque joueur **présente 1 champ de bataille** tiré au hasard parmi ses 3 : en duel, il y a donc **2 champs de bataille** sur la table.",
      "La **légende** va dans la zone de légende, le **champion élu** dans la zone de champion — visibles de tous, dès le début.",
      "Chacun **pioche 4 cartes**, puis peut faire un **mulligan** : mettre de côté jusqu'à 2 cartes, repiocher autant, recycler celles mises de côté."
    ],
    scene: {
      cards: table(),
      hand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "but",
    title: "Le but : 8 points",
    ref: "193",
    terms: ["conquête", "occupation", "score de la victoire"],
    text: [
      "**Conquête** : vous prenez le contrôle d'un champ de bataille → **1 point immédiatement**.",
      "**Occupation** : au début de votre tour, chaque champ de bataille que vous contrôlez encore rapporte **1 point**.",
      "Un champ de bataille ne peut vous rapporter qu'**un point par tour**. Premier à **8 points** avec l'avance : victoire."
    ],
    scene: {
      cards: table([{ key: "poro", card: CARDS.poro, spot: SPOTS.onBfYouA, might: true }]),
      control: { bfYou: "you" },
      score: { you: 2, foe: 1 },
      scorePulse: true
    }
  },
  {
    key: "debut-tour",
    title: "Le début du tour",
    ref: "315",
    terms: ["phase d'éveil", "étape des scores", "canaliser", "piocher"],
    text: [
      "**Phase d'éveil** : vous **préparez** tout ce que vous contrôlez (les cartes épuisées se redressent).",
      "**Phase de départ, étape des scores** : vous marquez pour chaque champ de bataille contrôlé — l'occupation.",
      "**Phase de canalisation** : vous **canalisez 2 runes** de votre deck de runes. Le joueur qui commence en second en canalise 3 à son tout premier tour.",
      "**Phase de pioche** : vous **piochez 1 carte**. Puis la phase principale commence."
    ],
    scene: {
      cards: table([
        { key: "runeA", card: CARDS.rune, spot: SPOTS.runeA, deal: true },
        { key: "runeB", card: CARDS.rune, spot: SPOTS.runeB, deal: true }
      ]),
      hand: 5,
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "energie",
    title: "Énergie et essence runique",
    ref: "160",
    terms: ["épuiser", "recycler", "réserve runique"],
    text: [
      "Le coût d'une carte : un **chiffre** (énergie) et parfois des **symboles de domaine** (essence runique).",
      "**Épuisez** une rune → **+1 énergie**. **Recyclez-la** (retour au deck de runes) → **1 essence** de son domaine. Ce sont des **Réactions** : utilisables à l'instant où un coût se paie.",
      "La **réserve runique se vide** au début de la phase principale et en fin de tour : rien ne se stocke d'un tour à l'autre."
    ],
    scene: {
      cards: table([
        { key: "runeA", card: CARDS.rune, spot: SPOTS.runeA, tapped: true },
        { key: "runeB", card: CARDS.rune, spot: SPOTS.runeB, tapped: true }
      ]),
      chips: { energy: 2, essence: 1 },
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "jouer",
    title: "Jouer des cartes",
    ref: "140",
    terms: ["épuisé", "préparé", "phase principale"],
    text: [
      "Une **unité** se joue dans votre **base** et arrive **épuisée** : elle attendra votre prochaine phase d'éveil (sauf mot-clé **Accélération**).",
      "Un **équipement** arrive **préparé** dans votre base. Un **sort** fait son effet puis part à la **défausse**.",
      "Ici : Stalwart Poro (2 énergie) et Sunlit Guardian (3) rejoignent la base, épuisés."
    ],
    scene: {
      cards: table([
        { key: "poro", card: CARDS.poro, spot: SPOTS.youBaseL, tapped: true, deal: true, might: true },
        { key: "guardian", card: CARDS.guardian, spot: SPOTS.youBaseM, tapped: true, deal: true, might: true },
        { key: "gear", card: CARDS.gear, spot: SPOTS.youBaseR, deal: true }
      ]),
      hand: 2,
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "deplacement",
    title: "Le déplacement standard",
    ref: "144",
    terms: ["déplacement standard", "contesté", "confrontation"],
    text: [
      "Au tour suivant, vos unités sont **préparées**. Le **déplacement standard** : **épuisez** une ou plusieurs unités pour aller de la base vers un champ de bataille (ou en revenir).",
      "Vos deux unités partent ensemble vers le champ de bataille adverse : il devient **contesté**.",
      "Une **confrontation** se prépare — et comme l'adversaire y a une unité, ce sera un **combat**."
    ],
    scene: {
      cards: table([
        { key: "poro", card: CARDS.poro, spot: SPOTS.onBfYouA, tapped: true, might: true },
        { key: "guardian", card: CARDS.guardian, spot: SPOTS.onBfYouB, tapped: true, might: true },
        { key: "foe2", card: CARDS.foe2, spot: SPOTS.onBfYouFoe, might: true }
      ]),
      arrow: { from: SPOTS.youBaseM, to: SPOTS.bfYou },
      contested: ["bfYou"],
      score: { you: 1, foe: 1 }
    }
  },
  {
    key: "confrontation",
    title: "Le combat : la confrontation",
    ref: "464",
    terms: ["attaquant", "défenseur", "chaîne", "Action", "Réaction"],
    text: [
      "Vous avez contesté : vous êtes l'**attaquant**, l'adversaire est le **défenseur**.",
      "La **confrontation de combat** s'ouvre : chacun, à tour de rôle, peut jouer des sorts **Action** ou **Réaction** — ils s'empilent dans la **chaîne**, le dernier joué se résout en premier.",
      "Vous jouez **Defy** pour protéger vos unités. Quand les deux joueurs **passent** l'un après l'autre, on passe aux dégâts."
    ],
    scene: {
      cards: table([
        { key: "poro", card: CARDS.poro, spot: SPOTS.onBfYouA, tapped: true, might: true },
        { key: "guardian", card: CARDS.guardian, spot: SPOTS.onBfYouB, tapped: true, might: true },
        { key: "foe2", card: CARDS.foe2, spot: SPOTS.onBfYouFoe, might: true },
        { key: "spell", card: CARDS.spell, spot: SPOTS.spellPlayed, deal: true, glow: true }
      ]),
      contested: ["bfYou"],
      clash: true,
      score: { you: 1, foe: 1 }
    }
  },
  {
    key: "degats",
    title: "L'étape des dégâts de combat",
    ref: "465",
    terms: ["puissance", "dégâts mortels", "attribuer"],
    text: [
      "Chaque camp **additionne la puissance** de ses unités : vous 2 + 3 = **5**, l'adversaire **4**.",
      "Chacun **attribue** ses dégâts aux unités d'en face : une unité doit recevoir des **dégâts mortels** (≥ sa puissance) avant la suivante — jamais plus que le nécessaire.",
      "Vos 5 dégâts éliminent Noxus Hopeful (4). Ses 4 dégâts : 3 sur Sunlit Guardian (mortels), 1 sur le Poro (il tient). Tout est infligé **simultanément**."
    ],
    scene: {
      cards: table([
        { key: "poro", card: CARDS.poro, spot: SPOTS.onBfYouA, tapped: true, might: true, dmg: 1 },
        { key: "guardian", card: CARDS.guardian, spot: SPOTS.onBfYouB, tapped: true, might: true, dmg: 3, dead: true },
        { key: "foe2", card: CARDS.foe2, spot: SPOTS.onBfYouFoe, might: true, dmg: 4, dead: true }
      ]),
      contested: ["bfYou"],
      score: { you: 1, foe: 1 }
    }
  },
  {
    key: "resolution",
    title: "Résolution, conquête, fin de tour",
    ref: "466",
    terms: ["nettoyage", "conquête", "fin de tour", "exténuation"],
    text: [
      "**Nettoyage de combat** : les éliminés partent à la défausse, les survivants sont **soignés**. Seul camp restant : vous prenez le contrôle → **conquête, +1 point**.",
      "**Fin de tour** : toutes les unités sont soignées, les effets « pendant ce tour » expirent, la réserve runique se vide. Au joueur suivant.",
      "Dernier détail : pour marquer le **point de la victoire** par conquête, il faut avoir marqué sur **chaque** champ de bataille ce tour-là — sinon, on pioche une carte à la place. Bonne partie !"
    ],
    scene: {
      cards: table([{ key: "poro", card: CARDS.poro, spot: SPOTS.onBfYouA, might: true }]),
      control: { bfYou: "you" },
      score: { you: 2, foe: 1 },
      scorePulse: true
    }
  }
]
