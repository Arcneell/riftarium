/* Guide de prise en main : une partie de duel (1c1) rejouée de A à Z sur la
   disposition du tapis officiel. Cartes réelles du set Origins (démonstration
   avec un deck Jinx face à un camp Yasuo), visuels servis par le CDN Riot.
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
   Piste de score verticale sur le côté. L'adversaire est en miroir,
   les champs de bataille au centre de la table. */
export const SPOTS = {
  bfFoe: { x: 39, y: 44 },
  bfYou: { x: 61, y: 44 },

  legend: { x: 8, y: 61 },
  championZone: { x: 16.5, y: 61 },
  mainDeck: { x: 92, y: 61 },
  runeDeck: { x: 8, y: 79 },
  discard: { x: 92, y: 79 },

  youBaseA: { x: 33, y: 61 },
  youBaseB: { x: 41, y: 61 },
  youBaseC: { x: 49, y: 61 },

  runeA: { x: 19, y: 79 },
  runeB: { x: 25.5, y: 79 },
  runeC: { x: 32, y: 79 },
  runeD: { x: 38.5, y: 79 },
  runeE: { x: 45, y: 79 },
  runeF: { x: 51.5, y: 79 },

  hand1: { x: 57, y: 93 },
  hand2: { x: 63.5, y: 93 },
  hand3: { x: 70, y: 93 },
  hand4: { x: 76.5, y: 93 },
  hand5: { x: 83, y: 93 },

  foeLegend: { x: 92, y: 22 },
  foeChampion: { x: 83.5, y: 22 },
  foeMainDeck: { x: 8, y: 22 },
  foeRuneDeck: { x: 92, y: 8 },
  foeDiscard: { x: 8, y: 8 },
  foeBaseA: { x: 45, y: 22 },

  onBfFoeA: { x: 33.5, y: 47 },
  onBfFoeB: { x: 45, y: 47 },
  onBfFoeDef: { x: 39, y: 35 },
  onBfYouA: { x: 61, y: 47 },

  chain: { x: 50, y: 60 },

  discardA: { x: 92, y: 80 },
  discardB: { x: 91.2, y: 78.6, r: -9 },
  discardC: { x: 92.8, y: 77.2, r: 8 },
  foeDiscardA: { x: 8, y: 8, r: 7 }
}

const fan = (index, count, y = 42, spread = 10.5) => ({
  x: 50 + (index - (count - 1) / 2) * spread,
  y,
  r: (index - (count - 1) / 2) * 4
})

/* Zones fixes une fois la table installée. */
const board = (extra = []) => {
  const cards = [
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
  const byKey = new Map()
  for (const card of cards) byKey.set(card.key, card)
  return [...byKey.values()]
}

/* Votre main de départ : 4 vraies cartes, faces visibles. */
const HAND = [
  { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
  { key: "h2", card: CARDS.rearguard, spot: SPOTS.hand2, hand: true },
  { key: "h3", card: CARDS.gear, spot: SPOTS.hand3, hand: true },
  { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand4, hand: true }
]

/* Zone de runes : positions fixes, clés stables pour animer chaque rune.
   rune0 (Fureur) sera recyclée au tour 1 ; les suivantes arrivent 2 par tour. */
const RUNE_SPOTS = [SPOTS.runeA, SPOTS.runeB, SPOTS.runeC, SPOTS.runeD, SPOTS.runeE, SPOTS.runeF]
const runes = (list) =>
  list.map((r, i) => ({
    key: r.k,
    card: r.d === "F" ? CARDS.furyRune : CARDS.chaosRune,
    spot: RUNE_SPOTS[i],
    tapped: !!r.t
  }))

export const STEPS = [
  {
    key: "materiel",
    title: "Ce qu'il faut pour jouer",
    ref: "101",
    terms: ["deck principal", "deck de runes", "légende de champion", "champion élu"],
    text: [
      "Quatre éléments : un **deck principal** d'au moins 40 cartes (unités, sorts, équipements), un **deck de runes** de 12 runes, une **légende de champion** et 3 **champs de bataille**.",
      "La légende fixe les **domaines** du deck — ici Fureur + Chaos pour la démonstration : chaque carte du deck doit appartenir à ces domaines.",
      "Le **champion élu** est une carte du deck mise à part : elle commence la partie visible, dans sa propre zone. Vous la jouerez plus tard, comme si elle était dans votre main."
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
    ref: "107",
    terms: ["base", "zone de légende", "zone de champion", "défausse"],
    text: [
      "Votre moitié suit le tapis officiel : **légende** et **champion élu** à gauche, votre **base** au centre, **deck principal** à droite. En dessous : **deck de runes**, zone de **runes**, **défausse** — et votre main. Votre score se lit sur la piste verticale, de bas en haut.",
      "Au centre, **2 champs de bataille** : chaque joueur en présente 1, tiré au hasard parmi ses 3 (les 2 autres ne serviront pas cette partie).",
      "L'adversaire est installé en miroir, en haut. Tout ce qui est sur la table est public — seules les mains restent secrètes."
    ],
    scene: {
      cards: board(),
      foeHand: 0,
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
      cards: board([{ key: "u1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true }]),
      control: { bfFoe: "you" },
      foeHand: 0,
      score: { you: 1, foe: 0 },
      scorePulse: true
    }
  },
  {
    key: "main-depart",
    title: "Main de départ et mulligan",
    ref: "110",
    terms: ["piocher", "mulligan", "recycler"],
    text: [
      "Chaque joueur **pioche 4 cartes** — les vôtres sont là, faces visibles. On détermine au hasard qui commence : ce sera vous.",
      "Main décevante ? Un seul **mulligan** : mettez jusqu'à **2 cartes de côté**, piochez-en autant, puis **recyclez** celles mises de côté : elles sont placées **sous votre deck principal**.",
      "Ici, on garde les 4 cartes."
    ],
    scene: {
      cards: board(HAND.map((c) => ({ ...c, glow: true }))),
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "debut-tour",
    title: "Le début de chaque tour",
    ref: "315",
    terms: ["phase d'éveil", "canaliser", "piocher"],
    text: [
      "**Éveil** : vous redressez (**préparez**) toutes vos cartes épuisées.",
      "**Étape des scores** : vous marquez 1 point par champ de bataille contrôlé.",
      "**Canalisation** : **2 runes** passent du deck de runes à votre zone de runes. Elles **restent en zone de runes de tour en tour** : 2 au premier tour, 4 au deuxième, 6 au troisième. (Le joueur qui commence en second en canalise 3 à son tout premier tour.)",
      "**Pioche** : **1 carte** — suivez-la, elle glisse du deck principal vers votre main : Get Excited!, le sort signature de Jinx."
    ],
    scene: {
      cards: board([
        ...HAND,
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true, glow: true },
        ...runes([
          { k: "rune0", d: "F" },
          { k: "rune1", d: "C" }
        ])
      ]),
      arrow: { from: { x: 92, y: 54 }, to: { x: 85, y: 87 } },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "energie",
    title: "Payer ses cartes : énergie et essence",
    ref: "160",
    terms: ["épuiser", "recycler", "énergie", "essence runique"],
    text: [
      "Lisez la carte en gros plan — Jinx - Demolitionist. **① Le chiffre** : le coût en **énergie**. **② Les symboles de domaine** en dessous : le coût en **essence runique**. **③ La puissance** de l'unité. **④ Ses mots-clés et effets**. (Cliquez n'importe quelle carte de la table pour la lire en grand.)",
      "Chaque rune de votre zone paie ces coûts de deux façons. **L'épuiser** (la tourner) : **+1 énergie** — elle se redressera à votre prochain éveil. **La recycler** : **+1 essence** de son domaine — la rune est glissée **sous votre deck de runes** (règle 416) et reviendra quand vous la canaliserez.",
      "On épuise pour les chiffres ; on ne recycle que pour les symboles de domaine.",
      "Votre main : Legion Rearguard coûte **2 énergie**, Seal of Rage **0 énergie + 1 symbole Fureur**. Vous avez exactement de quoi jouer les deux."
    ],
    scene: {
      cards: board([
        ...HAND,
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand5, hand: true },
        ...runes([
          { k: "rune0", d: "F" },
          { k: "rune1", d: "C" }
        ])
      ]),
      focus: {
        card: CARDS.demolitionist,
        notes: [
          { n: 1, x: 12, y: 8.5 },
          { n: 2, x: 12, y: 20 },
          { n: 3, x: 88, y: 8.5 },
          { n: 4, x: 50, y: 76 }
        ]
      },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "jouer",
    title: "Tour 1 : jouer une unité",
    ref: "140",
    terms: ["épuisé", "préparé", "phase principale", "Accélération"],
    text: [
      "Vous **épuisez vos 2 runes** : 2 énergie, le coût exact de **Legion Rearguard**. Il quitte votre main et entre dans votre **base**, **épuisé** — couché sur le côté, il ne fera rien ce tour-ci.",
      "Son texte propose **Accélération** : payer 1 énergie + 1 Fureur de plus pour qu'il arrive **préparé**. Vous n'avez plus de quoi payer — ce sera pour une autre partie.",
      "Les unités, équipements et sorts se jouent pendant votre **phase principale**, dans l'ordre que vous voulez, tant que vos runes peuvent payer."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.hand2, hand: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand3, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand4, hand: true },
        ...runes([
          { k: "rune0", d: "F", t: true },
          { k: "rune1", d: "C", t: true }
        ])
      ]),
      chips: { energy: 2 },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "recycler",
    title: "Tour 1 : payer une essence en recyclant",
    ref: "416",
    terms: ["recycler", "essence runique", "Réaction"],
    text: [
      "**Seal of Rage** coûte 0 énergie + **1 symbole Fureur**. Vos runes sont épuisées, mais une rune épuisée peut toujours être **recyclée**.",
      "Vous recyclez votre **Fury Rune** : regardez-la glisser **sous le deck de runes**. Elle produit 1 essence Fureur, qui paie l'équipement. Il ne reste qu'une rune en zone.",
      "Seal of Rage arrive **préparé** (c'est un équipement) — et lisez son texte : « Épuiser : Réaction — Ajoutez 1 Fureur. » Il produira lui-même de l'essence Fureur, à n'importe quel moment où un coût se paie. Fin de votre tour 1."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand2, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand3, hand: true },
        { key: "rune0", card: CARDS.furyRune, spot: { x: 9.5, y: 76.5, r: -6 }, ghost: true },
        ...runes([{ k: "runePad", d: "F", t: true }]).slice(1),
        { key: "rune1", card: CARDS.chaosRune, spot: SPOTS.runeA, tapped: true }
      ]),
      arrow: { from: { x: 22, y: 79 }, to: { x: 12, y: 78 } },
      chips: { essence: 1 },
      foeHand: 4,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "tour-adverse",
    title: "Le tour de l'adversaire",
    ref: "301",
    terms: ["joueur du tour", "ordre des tours"],
    text: [
      "À lui : mêmes phases, dans le même ordre. Il canalise **3 runes** (bonus du joueur qui commence en second), pioche, puis joue **Sunlit Guardian** dans **sa** base — **épuisé**, comme toute unité qui arrive.",
      "Lisez sa carte : **Bouclier** (+1 puissance quand il défend) et **Tank** (les dégâts de combat doivent lui être attribués en premier). Un défenseur né.",
      "Il termine son tour. Les tours alternent ainsi jusqu'à 8 points."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.hand1, hand: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand2, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand3, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.foeBaseA, tapped: true, might: true },
        { key: "rune1", card: CARDS.chaosRune, spot: SPOTS.runeA, tapped: true }
      ]),
      foeHand: 3,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "tour2",
    title: "Votre tour 2 : trois runes en jeu",
    ref: "165",
    terms: ["phase d'éveil", "canaliser"],
    text: [
      "Votre **éveil** redresse Legion Rearguard et votre rune. Vous **canalisez 2 runes** : 3 en zone de runes. Vous piochez.",
      "3 runes épuisées = 3 énergie : **Flame Chompers** (coût 3) entre en jeu dans votre base, **épuisé**. Remarquez Sunlit Guardian : lui reste épuisé — une carte ne se **prépare** qu'à l'éveil de **son** propriétaire.",
      "Votre base tient maintenant deux unités et un équipement. Fin de votre tour 2."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.youBaseC, tapped: true, might: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand2, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.foeBaseA, tapped: true, might: true },
        ...runes([
          { k: "rune1", d: "C", t: true },
          { k: "rune2", d: "F", t: true },
          { k: "rune3", d: "C", t: true }
        ])
      ]),
      chips: { energy: 3 },
      foeHand: 3,
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "tour2-adverse",
    title: "Son tour 2 : il prend son champ de bataille",
    ref: "144",
    terms: ["déplacement standard", "conquête"],
    text: [
      "**Son éveil prépare Sunlit Guardian** — voilà pourquoi il ne pouvait pas bouger avant : une unité arrive épuisée et attend l'éveil suivant de son propriétaire.",
      "Il fait son **déplacement standard** : Guardian s'épuise et marche sur le **Monastery of Hirana**, son champ de bataille. Personne n'y était : il en prend le contrôle → **conquête, 1 point pour lui**.",
      "Au début de **son** prochain tour, ce champ lui rapportera encore 1 point d'**occupation** — si vous le laissez faire."
    ],
    scene: {
      cards: board([
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.youBaseA, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h1", card: CARDS.chompers, spot: SPOTS.youBaseC, tapped: true, might: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand2, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, tapped: true, might: true },
        ...runes([
          { k: "rune1", d: "C" },
          { k: "rune2", d: "F" },
          { k: "rune3", d: "C" }
        ])
      ]),
      arrow: { from: { x: 45, y: 26 }, to: { x: 40, y: 32 } },
      control: { bfFoe: "foe" },
      foeHand: 3,
      score: { you: 0, foe: 1 },
      scorePulse: true
    }
  },
  {
    key: "deplacement",
    title: "Votre tour 3 : à l'assaut",
    ref: "144",
    terms: ["déplacement standard", "contesté"],
    text: [
      "Éveil (tout se redresse), canalisation (**5 runes**), pioche. Au passage, votre **légende** travaille pour vous : Jinx - Loose Cannon fait piocher 1 carte au début de votre phase de départ si votre main compte 1 carte ou moins — un filet de sécurité permanent.",
      "Vos deux unités, **préparées**, s'épuisent pour un **déplacement standard** groupé vers le Monastery of Hirana. (De la base vers un champ, ou l'inverse — jamais de champ à champ, sauf mot-clé **Gank**.)",
      "Le champ devient **contesté** : deux joueurs y ont des unités, un **combat** se prépare."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.hand1, hand: true },
        { key: "h5", card: CARDS.spell, spot: SPOTS.hand2, hand: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true },
        ...runes([
          { k: "rune1", d: "C" },
          { k: "rune2", d: "F" },
          { k: "rune3", d: "C" },
          { k: "rune4", d: "F" },
          { k: "rune5", d: "C" }
        ])
      ]),
      arrow: { from: { x: 40, y: 57 }, to: { x: 38, y: 52 } },
      contested: ["bfFoe"],
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "confrontation",
    title: "La confrontation : le duel de sorts",
    ref: "464",
    terms: ["attaquant", "défenseur", "chaîne", "Action"],
    text: [
      "Vous avez contesté : vous êtes l'**attaquant**, lui le **défenseur**. Avant les dégâts, la **confrontation** : chacun à son tour joue un sort **Action** ou **Réaction**, ou **passe** — les sorts s'empilent dans la **chaîne** et se résolvent du dernier au premier.",
      "**Get Excited!** (Action, 2 énergie + 1 Fureur) : vous épuisez 2 runes pour l'énergie et **épuisez Seal of Rage** pour l'essence Fureur — sa Réaction produit au moment exact où un coût se paie.",
      "Son effet : **défaussez 1 carte, infligez son coût en énergie en dégâts** à une unité du champ. Vous défaussez Jinx - Demolitionist (coût 3) : **3 dégâts** sur Sunlit Guardian. En défense, son **Bouclier** porte sa puissance à 4 : il tient, marqué de 3 dégâts.",
      "Les deux joueurs passent : place aux dégâts de combat."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB, tapped: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.discardA },
        { key: "h5", card: CARDS.spell, spot: SPOTS.chain, glow: true },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true, dmg: 3 },
        ...runes([
          { k: "rune1", d: "C", t: true },
          { k: "rune2", d: "F", t: true },
          { k: "rune3", d: "C" },
          { k: "rune4", d: "F" },
          { k: "rune5", d: "C" }
        ])
      ]),
      contested: ["bfFoe"],
      clash: true,
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "degats",
    title: "Les dégâts de combat",
    ref: "465",
    terms: ["puissance", "dégâts mortels", "attribuer", "Tank"],
    text: [
      "Chaque camp additionne la **puissance** de ses unités : vous 3 + 2 = **5**. Lui : 3 + 1 de **Bouclier** = **4**.",
      "Vous attribuez vos 5 dégâts : **Tank** oblige à viser Guardian d'abord — il porte déjà 3 dégâts, 1 de plus suffit pour des **dégâts mortels** (4 ≥ 4). Le reste lui est attribué faute d'autre cible.",
      "Il attribue ses 4 : 2 éliminent Legion Rearguard (**mortels**), les 2 restants marquent Flame Chompers (3 de puissance : il tient). Tout est infligé **simultanément**."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true, dmg: 2 },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.onBfFoeB, tapped: true, might: true, dmg: 2, dead: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB, tapped: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.discardA },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.onBfFoeDef, might: true, dmg: 5, dead: true },
        ...runes([
          { k: "rune1", d: "C", t: true },
          { k: "rune2", d: "F", t: true },
          { k: "rune3", d: "C" },
          { k: "rune4", d: "F" },
          { k: "rune5", d: "C" }
        ])
      ]),
      contested: ["bfFoe"],
      foeHand: 3,
      score: { you: 0, foe: 1 }
    }
  },
  {
    key: "conquete",
    title: "Résolution : la conquête",
    ref: "466",
    terms: ["nettoyage", "conquête", "soigner"],
    text: [
      "**Nettoyage de combat** : chaque carte éliminée part dans la **défausse de son propriétaire** — Legion Rearguard rejoint Get Excited! et Jinx - Demolitionist dans la vôtre, Sunlit Guardian part dans la sienne. Les survivants sont **soignés** : Flame Chompers repart à pleine puissance.",
      "Seul camp restant sur le champ : vous en prenez le **contrôle** → **conquête, +1 point**, immédiatement.",
      "Si les **deux** camps avaient survécu, les attaquants auraient été **rappelés** à leur base et le défenseur aurait gardé le contrôle."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB, tapped: true },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.discardA },
        { key: "h5", card: CARDS.spell, spot: SPOTS.discardB },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.discardC },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.foeDiscardA },
        ...runes([
          { k: "rune1", d: "C", t: true },
          { k: "rune2", d: "F", t: true },
          { k: "rune3", d: "C" },
          { k: "rune4", d: "F" },
          { k: "rune5", d: "C" }
        ])
      ]),
      control: { bfFoe: "you" },
      arrow: { from: { x: 48, y: 47 }, to: { x: 87, y: 76 } },
      foeHand: 3,
      score: { you: 1, foe: 1 },
      scorePulse: true
    }
  },
  {
    key: "champion-elu",
    title: "Votre tour 4 : le champion élu entre en scène",
    ref: "108",
    terms: ["occupation", "zone de champion", "recycler"],
    text: [
      "Début de votre tour 4 : à l'**étape des scores**, le champ que vous tenez rapporte **+1 point d'occupation**. Éveil, canalisation (**7 runes** — 6 affichées ici), pioche.",
      "Place au **champion élu** : **Jinx - Rebel** (5 énergie + 1 symbole Chaos) se joue **depuis sa zone de champion**, exactement comme depuis votre main. Vous épuisez 5 runes et **recyclez une Chaos Rune** pour le symbole.",
      "Elle entre en jeu **épuisée**, dans votre base. Si elle est éliminée, elle ira à la défausse comme n'importe quelle carte — la zone de champion ne sert qu'au départ."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true },
        { key: "chosen", card: CARDS.chosen, spot: SPOTS.youBaseA, tapped: true, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.discardA },
        { key: "h5", card: CARDS.spell, spot: SPOTS.discardB },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.discardC },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.foeDiscardA },
        ...runes([
          { k: "rune1", d: "C", t: true },
          { k: "rune2", d: "F", t: true },
          { k: "rune3", d: "C", t: true },
          { k: "rune4", d: "F", t: true },
          { k: "rune5", d: "C", t: true },
          { k: "rune6", d: "F" }
        ])
      ]),
      control: { bfFoe: "you" },
      chips: { energy: 5, essence: 1 },
      foeHand: 3,
      score: { you: 2, foe: 1 },
      scorePulse: true
    }
  },
  {
    key: "victoire",
    title: "Les deux façons de gagner",
    ref: "193",
    terms: ["score de la victoire", "conquête", "occupation", "exténuation"],
    text: [
      "La rapide : **conquérir les 2 champs de bataille dans le même tour** — le point de la victoire par conquête n'est accordé que si vous avez marqué sur chaque champ ce tour-là (sinon, vous piochez une carte à la place).",
      "La patiente : **tenir un champ** et laisser l'**occupation**, sans restriction, vous porter à 8.",
      "Cas particulier : si vous devez piocher avec un deck principal vide, vous êtes **exténué** — votre défausse est remélangée en un nouveau deck et un adversaire de votre choix gagne 1 point.",
      "Vous savez jouer. Pour chaque mécanique en détail, direction l'**aide avancée** — et le texte officiel tranche toujours."
    ],
    scene: {
      cards: board([
        { key: "h1", card: CARDS.chompers, spot: SPOTS.onBfFoeA, might: true },
        { key: "chosen", card: CARDS.chosen, spot: SPOTS.onBfYouA, might: true },
        { key: "h3", card: CARDS.gear, spot: SPOTS.youBaseB },
        { key: "h4", card: CARDS.demolitionist, spot: SPOTS.discardA },
        { key: "h5", card: CARDS.spell, spot: SPOTS.discardB },
        { key: "h2", card: CARDS.rearguard, spot: SPOTS.discardC },
        { key: "def", card: CARDS.foeUnit, spot: SPOTS.foeDiscardA },
        ...runes([
          { k: "rune1", d: "C" },
          { k: "rune2", d: "F" },
          { k: "rune3", d: "C" },
          { k: "rune4", d: "F" },
          { k: "rune5", d: "C" },
          { k: "rune6", d: "F" }
        ])
      ]),
      control: { bfFoe: "you", bfYou: "you" },
      foeHand: 3,
      score: { you: 8, foe: 4 },
      scorePulse: true
    }
  }
]
