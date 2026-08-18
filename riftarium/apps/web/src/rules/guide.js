/* Guide de prise en main : une partie de duel (1c1) rejouée sur la disposition
   du tapis officiel. Cartes réelles du set Origins (démonstration avec un deck
   Jinx face à un camp Yasuo), visuels servis par le CDN officiel Riot.
   Contenu conforme aux règles officielles (numéros de règle dans `ref`). */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live"
const img = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=360&accountingTag=RB`
const imgWide = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=560&accountingTag=RB`

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

/* La disposition du tapis officiel, en % du plateau (translate(-50%,-50%)).
   Votre moitié, en bas — rangée du milieu : légende + champion élu à gauche,
   BASE au centre, deck principal à droite ; rangée du bas : deck de runes à
   gauche, zone RUNES au centre, défausse à droite, votre main à côté.
   Piste de score verticale sur le côté. L'adversaire est installé en miroir,
   les champs de bataille au centre de la table. */
export const SPOTS = {
  bfFoe: { x: 39, y: 44 },
  bfYou: { x: 61, y: 44 },

  legend: { x: 8, y: 64 },
  championZone: { x: 16.5, y: 64 },
  mainDeck: { x: 92, y: 64 },
  runeDeck: { x: 8, y: 86 },
  discard: { x: 92, y: 86 },

  youBaseA: { x: 30, y: 64 },
  youBaseB: { x: 38, y: 64 },
  youBaseC: { x: 46, y: 64 },

  runeA: { x: 20, y: 86 },
  runeB: { x: 27, y: 86 },
  runeC: { x: 34, y: 86 },
  runeD: { x: 41, y: 86 },

  hand1: { x: 55, y: 89 },
  hand2: { x: 62, y: 89 },
  hand3: { x: 69, y: 89 },
  hand4: { x: 76, y: 89 },
  hand5: { x: 83, y: 89 },

  foeLegend: { x: 92, y: 24 },
  foeChampion: { x: 83.5, y: 24 },
  foeMainDeck: { x: 8, y: 24 },
  foeRuneDeck: { x: 92, y: 6.5 },
  foeDiscard: { x: 8, y: 6.5 },
  foeBaseA: { x: 45, y: 24 },

  onBfFoeA: { x: 33.5, y: 48 },
  onBfFoeB: { x: 45, y: 48 },
  onBfFoeDef: { x: 39, y: 36.5 },

  chain: { x: 50, y: 61 }
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
  { key: "foeLegend", card: CARDS.foeLegend, spot: SPOTS.foeLegend, label: "Sa légende" },
  { key: "foeChosen", card: CARDS.foeChosen, spot: SPOTS.foeChampion, label: "Son champion" },
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

/* Les 2 runes canalisées au tour 1 — elles restent en zone de runes tant
   qu'on ne les recycle pas. Au tour 2, 2 de plus : le total grandit chaque tour. */
const RUNES_T1 = (tapped = false) => [
  { key: "runeA", card: CARDS.furyRune, spot: SPOTS.runeA, tapped },
  { key: "runeB", card: CARDS.chaosRune, spot: SPOTS.runeB, tapped }
]
const RUNES_T2 = (tappedCount = 0) => [
  { key: "runeA", card: CARDS.furyRune, spot: SPOTS.runeA, tapped: tappedCount > 0 },
  { key: "runeB", card: CARDS.chaosRune, spot: SPOTS.runeB, tapped: tappedCount > 1 },
  { key: "runeC", card: CARDS.furyRune, spot: SPOTS.runeC, tapped: tappedCount > 2 },
  { key: "runeD", card: CARDS.chaosRune, spot: SPOTS.runeD, tapped: tappedCount > 3 }
]

export const STEPS = [
  {
    key: "materiel",
    title: "Ce qu'il faut pour jouer",
    ref: "101",
    terms: ["deck principal", "deck de runes", "légende de champion", "champion élu"],
    text: [
      "Quatre éléments : un **deck principal** d'au moins 40 cartes (unités, sorts, équipements), un **deck de runes** de 12 runes, une **légende de champion** et 3 **champs de bataille**.",
      "La légende fixe les **domaines** du deck — ici Fureur + Chaos pour la démonstration : chaque carte du deck doit appartenir à ces domaines.",
      "Le **champion élu** est une carte du deck mise à part : elle commence la partie visible, dans sa propre zone, jouable comme si elle était dans votre main."
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
    title: "La table, zone par zone",
    ref: "110",
    terms: ["base", "zone de légende", "zone de champion", "mulligan"],
    text: [
      "Votre moitié de table suit le tapis officiel : **légende** et **champion élu** à gauche, votre **base** au centre, **deck principal** à droite. Rangée du bas : **deck de runes**, zone de **runes**, **défausse** — et votre main. Votre score se lit sur la piste verticale, de bas en haut.",
      "Au centre, **2 champs de bataille** : chaque joueur en présente 1, tiré au hasard parmi ses 3. L'adversaire est installé en miroir, en haut.",
      "Chacun **pioche 4 cartes**. Main décevante ? **Mulligan** : jusqu'à 2 cartes mises de côté, repiochées, puis recyclées dans le deck."
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
      "Seuls les champs de bataille rapportent des points, de deux façons.",
      "**Conquête** : à l'instant où vous prenez le contrôle d'un champ de bataille, **+1 point**.",
      "**Occupation** : au début de **votre** tour, chaque champ de bataille encore sous votre contrôle rapporte **+1 point**.",
      "Un même champ ne peut vous rapporter qu'un point par tour. Premier à **8** : victoire."
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
    title: "Le début de chaque tour",
    ref: "315",
    terms: ["phase d'éveil", "canaliser", "piocher"],
    text: [
      "**Éveil** : vous redressez (**préparez**) toutes vos cartes épuisées. **Scores** : vous marquez pour chaque champ de bataille contrôlé.",
      "**Canalisation** : **2 runes** passent du deck de runes à votre zone de runes. Elles y **restent de tour en tour** — 2 au premier tour, 4 au deuxième, 6 au troisième : c'est votre moteur de ressources qui grandit. (Le second joueur en canalise 3 à son tout premier tour.)",
      "**Pioche** : **1 carte** — suivez-la, elle glisse du deck principal vers votre main : Get Excited!."
    ],
    scene: {
      cards: board([
        ...HAND,
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true, glow: true },
        ...RUNES_T1()
      ]),
      arrow: { from: { x: 92, y: 57 }, to: { x: 85, y: 84 } },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "energie",
    title: "Les runes paient tout",
    ref: "160",
    terms: ["épuiser", "recycler", "énergie", "essence runique"],
    text: [
      "Le coût d'une carte, en haut à gauche : un **chiffre** (à payer en **énergie**) et parfois des **symboles de domaine** (à payer en **essence runique**).",
      "Chaque rune de votre zone offre deux usages. **L'épuiser** (la tourner) : **+1 énergie**, et elle se redresse à votre prochain éveil. **La recycler** (la rendre au deck de runes) : **+1 essence** de son domaine — la rune quitte la table, vous la recanaliserez plus tard.",
      "Réflexe de débutant : on **épuise** pour les chiffres, on ne **recycle** que pour les symboles de domaine.",
      "Ici vous épuisez vos 2 runes : **2 énergie** en réserve. Ce qui n'est pas dépensé se perd en fin de phase."
    ],
    scene: {
      cards: board([...HAND, { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true }, ...RUNES_T1(true)]),
      chips: { energy: 2 },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "jouer",
    title: "Jouer sa première unité",
    ref: "140",
    terms: ["épuisé", "préparé", "phase principale"],
    text: [
      "Vos 2 énergies paient **Legion Rearguard** (coût 2) : il quitte votre main et entre dans votre **base**, **épuisé** — couché sur le côté, il ne fera rien ce tour-ci (sauf mot-clé **Accélération**).",
      "**Seal of Rage** coûte 0 : posé aussi. Les équipements, eux, arrivent **préparés**, droits.",
      "**Flame Chompers** coûte 3 : vos 2 runes ne produisent que 2 énergie, il attendra le tour prochain. C'est toute la logique du jeu : chaque tour, 2 runes de plus, des cartes plus grosses.",
      "Vous terminez votre tour ; l'adversaire joue le sien de la même façon."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand2, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand3, hand: true },
        ...RUNES_T1(true)
      ]),
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "deplacement",
    title: "Deux tours plus tard : à l'assaut",
    ref: "144",
    terms: ["déplacement standard", "contesté"],
    text: [
      "Tour 2 : vous avez canalisé 2 runes de plus (**4 en zone de runes**) et joué **Flame Chompers** (coût 3). Tour 3 : l'éveil redresse tout le monde.",
      "Vos deux unités, **préparées**, font leur **déplacement standard** : elles s'**épuisent** pour marcher ensemble sur le **Monastery of Hirana**, le champ de bataille adverse — défendu par Sunlit Guardian.",
      "Le champ devient **contesté** : deux joueurs y ont des unités, un **combat** va se déclencher."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseC },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand2, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true },
        ...RUNES_T2()
      ]),
      arrow: { from: { x: 32, y: 61 }, to: { x: 36, y: 53 } },
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
      "Avant les dégâts, la **confrontation** : chacun à son tour joue un sort **Action** ou **Réaction**, ou **passe**. Les sorts s'empilent dans la **chaîne** et se résolvent du dernier joué au premier.",
      "Vous **épuisez 2 runes** (2 énergie) et jouez **Get Excited!** depuis votre main — vos runes servent à tout moment, même en pleine confrontation.",
      "L'adversaire passe, vous passez : la confrontation se termine, place aux dégâts."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseC },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.chain, glow: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true },
        ...RUNES_T2(2)
      ]),
      contested: ["bfFoe"],
      clash: true,
      chips: { energy: 2 },
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
      "Le sort résolu file à la **défausse**. Chaque camp additionne la **puissance** de ses unités sur place : vous 3 + 2 = **5**, lui **3**.",
      "Chacun **attribue** son total aux unités adverses, une par une : des **dégâts mortels** (au moins la puissance de l'unité) avant de passer à la suivante, et jamais plus que nécessaire.",
      "Ses 3 dégâts : 2 éliminent Legion Rearguard, le 1 restant égratigne Flame Chompers. Vos 5 écrasent Sunlit Guardian (3). Tout est infligé **simultanément**."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true, dmg: 1 },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true, dmg: 2, dead: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseC },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true, dmg: 5, dead: true },
        ...RUNES_T2(2)
      ]),
      contested: ["bfFoe"],
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "victoire",
    title: "Conquête, et les deux chemins vers la victoire",
    ref: "466",
    terms: ["nettoyage", "conquête", "occupation", "fin de tour"],
    text: [
      "**Nettoyage de combat** : les éliminés partent à la défausse, les survivants sont **soignés**. Flame Chompers reste seul : vous prenez le contrôle → **conquête, +1 point**.",
      "**Fin de tour** : soins pour tous, les effets « pendant ce tour » expirent, la réserve runique se vide — mais vos runes, elles, **restent en zone de runes** pour le tour suivant.",
      "Deux routes vers la victoire. La rapide : **conquérir les 2 champs de bataille dans le même tour** — le point de la victoire par conquête n'est accordé que si vous avez marqué sur chaque champ ce tour-là (sinon, vous piochez une carte à la place). La patiente : **tenir un champ** et laisser l'**occupation**, sans restriction, vous porter à 8."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseC },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        ...RUNES_T2()
      ]),
      control: { bfFoe: "you" },
      foeHand: 3,
      score: { you: 1, foe: 1 },
      scorePulse: true
    }
  }
]
