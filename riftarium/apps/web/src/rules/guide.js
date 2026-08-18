/* Guide du débutant : une partie de duel (1c1) rejouée sur un tapis officiel,
   avec le deck préconstruit Jinx (Fureur/Chaos) face à un deck Yasuo (Calme).
   Cartes réelles du set Origins, visuels servis par le CDN officiel Riot.
   Contenu conforme aux règles officielles (numéros de règle dans `ref`). */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live"
const img = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=360&accountingTag=RB`
const imgWide = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=560&accountingTag=RB`

/* Le deck Jinx (vous) et le camp adverse (Yasuo). */
export const CARDS = {
  legend: {
    id: "ogn-251-298",
    name: "Jinx - Loose Cannon",
    img: img("f57c14381b126e9f5a7b5bc4913151cb24c14fc3-744x1039.png")
  },
  chosen: {
    id: "ogn-202-298",
    name: "Jinx - Rebel",
    might: 5,
    img: img("a7fe105f40df66525be51bd18e25506945a7b027-744x1039.png")
  },
  demolitionist: {
    id: "ogn-030-298",
    name: "Jinx - Demolitionist",
    might: 4,
    img: img("d6cac988aa7798945e550eba6841d3993868c4a4-744x1039.png")
  },
  chompers: {
    id: "ogn-006-298",
    name: "Flame Chompers",
    might: 3,
    img: img("1f6f5ebd18e5daac30d62626fddd785c4b457c2b-744x1039.png")
  },
  rearguard: {
    id: "ogn-010-298",
    name: "Legion Rearguard",
    might: 2,
    img: img("aedece01c7792c689050460db1670e6b9b15b61f-744x1039.png")
  },
  spell: {
    id: "ogn-008-298",
    name: "Get Excited!",
    img: img("2906c932c482af17fbb2979a8c42a6992f95d6a6-744x1039.png")
  },
  gear: {
    id: "ogn-040-298",
    name: "Seal of Rage",
    img: img("fbdd14adb40b0ca46b89f476a356fa21413d812e-744x1039.png")
  },
  furyRune: {
    id: "ogn-007-298",
    name: "Fury Rune",
    img: img("12bcd0cde5d9ff4640e82945001e9fef863530f1-744x1039.png")
  },
  chaosRune: {
    id: "ogn-166-298",
    name: "Chaos Rune",
    img: img("daf23b0deaa5e1a5a5d310b59e9ad25d1bd70363-744x1039.png")
  },
  bfYou: {
    id: "ogn-277-298",
    name: "Back-Alley Bar",
    img: imgWide("3e9f659a32e390b45bc87a01bdd6af4a8a3565f7-1038x744.png")
  },
  bfFoe: {
    id: "ogn-282-298",
    name: "Monastery of Hirana",
    img: imgWide("8767d9ed30e2873d3fa1045f973be229da56175d-1038x744.png")
  },
  foeLegend: {
    id: "ogn-259-298",
    name: "Yasuo - Unforgiven",
    img: img("68e4d3230b785738ae9d86f780f7f5607ef11807-744x1040.png")
  },
  foeChosen: {
    id: "ogn-205-298",
    name: "Yasuo - Windrider",
    might: 4,
    img: img("f5ba378ce4dad16d17e001814e091d5f484f2681-744x1039.png")
  },
  foeUnit: {
    id: "ogn-054-298",
    name: "Sunlit Guardian",
    might: 3,
    img: img("28bce7a662b9008f65565300f828d98790a641e1-744x1039.png")
  }
}

/* Le tapis officiel, en % du plateau (translate(-50%,-50%) appliqué).
   Vous, en bas : légende et champion élu à gauche, base au centre,
   défausse + deck principal + deck de runes à droite, main devant vous.
   L'adversaire est installé en miroir. Champs de bataille au centre. */
export const SPOTS = {
  bfFoe: { x: 39, y: 44 },
  bfYou: { x: 61, y: 44 },

  legend: { x: 6, y: 76 },
  championZone: { x: 14.5, y: 76 },
  discard: { x: 77, y: 76 },
  mainDeck: { x: 85.5, y: 76 },
  runeDeck: { x: 94, y: 76 },

  youBaseA: { x: 31, y: 63 },
  youBaseB: { x: 39, y: 63 },
  youBaseC: { x: 47, y: 63 },
  runeA: { x: 59, y: 63 },
  runeB: { x: 66, y: 63 },

  foeLegend: { x: 94, y: 12 },
  foeChampion: { x: 85.5, y: 12 },
  foeDiscard: { x: 23, y: 12 },
  foeMainDeck: { x: 14.5, y: 12 },
  foeRuneDeck: { x: 6, y: 12 },
  foeBaseA: { x: 43, y: 24 },

  onBfFoeA: { x: 33.5, y: 48 },
  onBfFoeB: { x: 45, y: 48 },
  onBfFoeDef: { x: 39, y: 36.5 },

  chain: { x: 50, y: 46 },

  hand1: { x: 34, y: 90 },
  hand2: { x: 42, y: 90 },
  hand3: { x: 50, y: 90 },
  hand4: { x: 58, y: 90 },
  hand5: { x: 66, y: 90 }
}

const fan = (index, count, y = 42, spread = 10.5) => ({
  x: 50 + (index - (count - 1) / 2) * spread,
  y,
  r: (index - (count - 1) / 2) * 4
})

/* Zones fixes une fois la table installée. */
const board = (extra = []) => [
  { key: "legend", card: CARDS.legend, spot: SPOTS.legend, label: "Légende" },
  { key: "chosen", card: CARDS.chosen, spot: SPOTS.championZone, label: "Champion élu" },
  { key: "mainDeck", card: CARDS.spell, spot: SPOTS.mainDeck, facedown: true, label: "Deck principal" },
  { key: "runeDeck", card: CARDS.furyRune, spot: SPOTS.runeDeck, facedown: true, label: "Deck de runes" },
  { key: "foeLegend", card: CARDS.foeLegend, spot: SPOTS.foeLegend, label: "Légende adverse" },
  { key: "foeChosen", card: CARDS.foeChosen, spot: SPOTS.foeChampion, label: "Champion adverse" },
  { key: "foeMainDeck", card: CARDS.spell, spot: SPOTS.foeMainDeck, facedown: true, label: "Son deck" },
  { key: "foeRuneDeck", card: CARDS.furyRune, spot: SPOTS.foeRuneDeck, facedown: true, label: "Ses runes" },
  ...extra
]

/* Votre main de départ : 4 vraies cartes, faces visibles. */
const HAND = [
  { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
  { key: "h2", card: CARDS.rearguard, spot: SPOTS.hand2, hand: true },
  { key: "h3", card: CARDS.gear, spot: SPOTS.hand3, hand: true },
  { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand4, hand: true }
]

export const STEPS = [
  {
    key: "materiel",
    title: "Le deck préconstruit Jinx",
    ref: "101",
    terms: ["deck principal", "deck de runes", "légende de champion", "champion élu"],
    text: [
      "Pour jouer, il vous faut quatre choses : un **deck principal** d'au moins 40 cartes (unités, sorts, équipements), un **deck de runes** d'exactement 12 runes, une **légende de champion** et 3 **champs de bataille**.",
      "Ici, le deck préconstruit **Jinx**. La légende **Jinx - Loose Cannon** donne ses domaines au deck (Fureur + Chaos) : toutes les cartes du deck doivent en faire partie.",
      "Le **champion élu** (Jinx - Rebel) est une carte du deck principal mise à part : elle commence la partie visible, dans sa propre zone, prête à être jouée."
    ],
    scene: {
      cards: [
        { key: "legend", card: CARDS.legend, spot: fan(0, 7), glow: true },
        { key: "chosen", card: CARDS.chosen, spot: fan(1, 7) },
        { key: "h1", card: CARDS.chompers, spot: fan(2, 7) },
        { key: "spellShow", card: CARDS.spell, spot: fan(3, 7) },
        { key: "runeShow", card: CARDS.furyRune, spot: fan(4, 7) },
        { key: "runeShow2", card: CARDS.chaosRune, spot: fan(5, 7) },
        { key: "bfShow", card: CARDS.bfYou, spot: fan(6, 7), wide: true }
      ],
      bare: true,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "mise-en-place",
    title: "La table, comme sur le tapis officiel",
    ref: "110",
    terms: ["zone de légende", "zone de champion", "base", "mulligan"],
    text: [
      "Chaque joueur **présente 1 champ de bataille** au hasard parmi ses 3 : en duel, **2 champs de bataille** au centre de la table. Votre Back-Alley Bar à droite, son Monastery of Hirana à gauche.",
      "Devant vous, votre **base** : vos unités, équipements et runes y entrent en jeu. À gauche, **légende** et **champion élu**. À droite, **défausse**, **deck principal**, **deck de runes**. L'adversaire est installé en miroir, en haut.",
      "Chacun **pioche 4 cartes** — les vôtres sont là, faces visibles. Main décevante ? **Mulligan** : mettez jusqu'à 2 cartes de côté, repiochez autant, recyclez-les."
    ],
    scene: {
      cards: board(HAND),
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "but",
    title: "Le but : 8 points",
    ref: "193",
    terms: ["conquête", "occupation", "score de la victoire"],
    text: [
      "Tout se joue sur les champs de bataille : eux seuls rapportent des points.",
      "**Conquête** : à l'instant où vous prenez le contrôle d'un champ de bataille, **+1 point**.",
      "**Occupation** : au début de **votre** tour, chaque champ de bataille encore sous votre contrôle rapporte **+1 point**.",
      "Un champ de bataille ne peut vous rapporter qu'un point par tour. Premier à **8 points** : victoire."
    ],
    scene: {
      cards: board([...HAND, { key: "u1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true }]),
      control: { bfFoe: "you" },
      foeHand: 4,
      score: { you: 1, foe: 0 },
      scorePulse: true
    }
  },
  {
    key: "debut-tour",
    title: "Votre tour commence",
    ref: "315",
    terms: ["phase d'éveil", "canaliser", "piocher"],
    text: [
      "Quatre phases automatiques ouvrent chaque tour, toujours dans le même ordre.",
      "**Éveil** : vous redressez (**préparez**) vos cartes épuisées. **Scores** : vous marquez pour chaque champ de bataille contrôlé.",
      "**Canalisation** : vous retournez **2 runes** de votre deck de runes, elles arrivent dans votre base. Le joueur qui commence en second en canalise **3** à son tout premier tour, pour compenser.",
      "**Pioche** : vous piochez **1 carte** — regardez-la glisser du deck vers votre main : **Get Excited!**, le sort signature de Jinx."
    ],
    scene: {
      cards: board([
        ...HAND,
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true, glow: true },
        { key: "runeA", card: CARDS.furyRune, spot: SPOTS.runeA },
        { key: "runeB", card: CARDS.chaosRune, spot: SPOTS.runeB }
      ]),
      arrow: { from: { x: 85.5, y: 69 }, to: { x: 67, y: 83 } },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "energie",
    title: "Payer ses cartes : énergie et essence",
    ref: "160",
    terms: ["épuiser", "recycler", "réserve runique"],
    text: [
      "Le coût d'une carte, en haut à gauche : un **chiffre** (énergie) et parfois des **symboles colorés** (essence runique du domaine correspondant).",
      "Chaque rune en jeu offre deux choix : l'**épuiser** (la tourner) pour **+1 énergie**, ou la **recycler** (la rendre au deck de runes) pour **1 essence** de son domaine.",
      "Le tout va dans votre **réserve runique**… qui se vide à la fin du tour : on ne stocke rien, on produit ce qu'on dépense."
    ],
    scene: {
      cards: board([
        ...HAND,
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true },
        { key: "runeA", card: CARDS.furyRune, spot: SPOTS.runeA, tapped: true },
        { key: "runeB", card: CARDS.chaosRune, spot: SPOTS.runeB, tapped: true }
      ]),
      chips: { energy: 2, essence: 1 },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "jouer",
    title: "Jouer des cartes depuis la main",
    ref: "140",
    terms: ["épuisé", "préparé", "phase principale"],
    text: [
      "Pendant votre **phase principale**, jouez autant de cartes que vos runes peuvent payer. Suivez-les : elles quittent votre main pour votre base.",
      "**Flame Chompers** (3) et **Legion Rearguard** (2) entrent en jeu **épuisés**, couchés sur le côté : une unité ne fait rien le tour de son arrivée (sauf **Accélération**).",
      "**Seal of Rage**, un équipement, arrive **préparé**, bien droit. Les sorts, eux, font leur effet puis partent à la défausse."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseC },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand4, hand: true },
        { key: "runeA", card: CARDS.furyRune, spot: SPOTS.runeA, tapped: true },
        { key: "runeB", card: CARDS.chaosRune, spot: SPOTS.runeB, tapped: true }
      ]),
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "deplacement",
    title: "Marcher sur un champ de bataille",
    ref: "144",
    terms: ["déplacement standard", "contesté"],
    text: [
      "Tour suivant : l'éveil a **préparé** vos unités. Elles peuvent enfin bouger : le **déplacement standard**, c'est s'**épuiser** pour aller de la base vers un champ de bataille (ou en revenir).",
      "Vos deux unités partent **ensemble** vers le Monastery of Hirana, le champ de bataille adverse — défendu par Sunlit Guardian.",
      "Le champ devient **contesté**. Deux joueurs y ont des unités : un **combat** va se déclencher."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: { x: 28, y: 64 } },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand4, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true }
      ]),
      arrow: { from: { x: 52, y: 66 }, to: { x: 46, y: 56 } },
      contested: ["bfFoe"],
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "confrontation",
    title: "La confrontation : le duel de sorts",
    ref: "464",
    terms: ["attaquant", "défenseur", "chaîne", "Action", "Réaction"],
    text: [
      "Vous avez contesté : vous êtes l'**attaquant**, lui le **défenseur**.",
      "Avant les dégâts, une **confrontation** : chacun à son tour peut jouer un sort **Action** ou **Réaction**, ou **passer**. Les sorts s'empilent dans la **chaîne** et se résolvent du dernier joué au premier.",
      "Vous jouez **Get Excited!** depuis votre main. L'adversaire passe, vous passez : la confrontation se termine, place aux dégâts."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: { x: 28, y: 64 } },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.chain, glow: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true }
      ]),
      contested: ["bfFoe"],
      clash: true,
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "degats",
    title: "Les dégâts : puissance contre puissance",
    ref: "465",
    terms: ["puissance", "dégâts mortels", "attribuer"],
    text: [
      "Chaque camp additionne la **puissance** de ses unités sur place. Vous : 3 + 2 = **5**. Lui : **3**.",
      "Chacun **attribue** son total aux unités adverses, une par une : il faut donner des **dégâts mortels** (au moins la puissance de l'unité) avant de passer à la suivante.",
      "Ses 3 dégâts : 2 éliminent Legion Rearguard, le 1 restant égratigne Flame Chompers. Vos 5 écrasent Sunlit Guardian. Tout est infligé **en même temps**."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true, dmg: 1 },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true, dmg: 2, dead: true },
        { key: "h3", card: CARDS.gear, spot: { x: 28, y: 64 } },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true, dmg: 5, dead: true }
      ]),
      contested: ["bfFoe"],
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "victoire",
    title: "Conquête, et le chemin vers la victoire",
    ref: "466",
    terms: ["nettoyage", "conquête", "occupation", "fin de tour"],
    text: [
      "**Nettoyage de combat** : les éliminés partent à la défausse, les survivants sont **soignés**. Flame Chompers reste seul : vous prenez le contrôle → **conquête, +1 point**.",
      "**Fin de tour** : tout le monde est soigné, les effets « pendant ce tour » expirent, la réserve runique se vide. À l'adversaire de jouer.",
      "Deux chemins vers la victoire en duel. Le rapide : **conquérir les 2 champs de bataille dans le même tour** — le dernier point par conquête n'est accordé que si vous avez marqué sur chaque champ ce tour-là (sinon, vous piochez une carte à la place). Le patient : **tenir un champ de bataille** et laisser l'**occupation**, sans restriction, vous porter à 8."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true },
        { key: "h3", card: CARDS.gear, spot: { x: 28, y: 64 } },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true }
      ]),
      control: { bfFoe: "you" },
      foeHand: 3,
      score: { you: 1, foe: 1 },
      scorePulse: true
    }
  }
]
