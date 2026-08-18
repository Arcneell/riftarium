/* Guide du débutant : chaque étape décrit une scène sur le plateau animé.
   Le contenu suit les règles officielles (numéros indiqués dans `ref`). */

/* Emplacements nommés du plateau (coordonnées du viewBox 900×560). */
export const ZONES = {
  foeBase: { x: 450, y: 88, w: 440, h: 96, label: "Base adverse" },
  bf1: { x: 190, y: 280, w: 220, h: 130, label: "Champ de bataille" },
  bf2: { x: 450, y: 280, w: 220, h: 130, label: "Champ de bataille" },
  bf3: { x: 710, y: 280, w: 220, h: 130, label: "Champ de bataille" },
  youBase: { x: 450, y: 472, w: 440, h: 96, label: "Votre base" }
}

/* Position d'un jeton dans une zone : petits décalages par index. */
export function slot(zone, index, count) {
  const z = ZONES[zone]
  const spread = Math.min(56, (z.w - 60) / Math.max(count, 1))
  const start = -((count - 1) * spread) / 2
  return { x: z.x + start + index * spread, y: z.y }
}

export const STEPS = [
  {
    key: "plateau",
    title: "Le plateau",
    ref: "107",
    text: [
      "Chaque joueur a une **base** : c'est là qu'arrivent vos unités et vos runes.",
      "Entre les deux, des **champs de bataille** (3 en duel). Ce sont eux que l'on se dispute : ils rapportent les points.",
      "À côté du plateau : votre main, votre deck principal, votre deck de 12 runes, votre légende et votre défausse."
    ],
    scene: {
      highlight: ["youBase", "foeBase", "bf1", "bf2", "bf3"],
      tokens: [],
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "but",
    title: "Le but : 8 points",
    ref: "193",
    text: [
      "Vous marquez **1 point** en prenant le contrôle d'un champ de bataille (**conquête**) ou en le contrôlant encore au début de votre tour (**occupation**).",
      "Chaque champ de bataille ne peut vous rapporter qu'**un point par tour**.",
      "Le premier joueur à **8 points** (et devant son adversaire) gagne la partie."
    ],
    scene: {
      highlight: ["bf1", "bf2", "bf3"],
      tokens: [{ id: "u1", zone: "bf1", side: "you", power: 3 }],
      control: { bf1: "you" },
      score: { you: 3, foe: 1 }
    }
  },
  {
    key: "mise-en-place",
    title: "La mise en place",
    ref: "110",
    text: [
      "Placez votre **légende** et votre **champion élu** dans leurs zones, vos champs de bataille sur la table.",
      "Mélangez séparément le deck principal et le deck de runes, puis **piochez 4 cartes**.",
      "**Mulligan** : vous pouvez mettre de côté jusqu'à 2 cartes, en piocher autant, puis recycler celles mises de côté."
    ],
    scene: {
      highlight: ["youBase"],
      hand: 4,
      tokens: [],
      score: { you: 0, foe: 0 }
    }
  },
  {
    key: "debut-tour",
    title: "Le début de votre tour",
    ref: "315",
    text: [
      "**Éveil** : préparez tout ce que vous contrôlez (redressez vos cartes épuisées).",
      "**Scores** : vous marquez 1 point par champ de bataille que vous contrôlez encore — c'est l'occupation.",
      "**Canalisation** : retournez **2 runes** de votre deck de runes.",
      "**Pioche** : piochez 1 carte."
    ],
    scene: {
      highlight: ["youBase", "bf2"],
      tokens: [{ id: "u1", zone: "bf2", side: "you", power: 3 }],
      control: { bf2: "you" },
      runes: 2,
      hand: 5,
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "energie",
    title: "Payer ses cartes : énergie et essence",
    ref: "160",
    text: [
      "Vos runes produisent deux ressources : de l'**énergie** (le chiffre du coût) et de l'**essence runique** (les symboles colorés du coût).",
      "Épuisez une rune pour **+1 énergie** ; recyclez-la pour **1 essence** de son domaine.",
      "La réserve **se vide** entre les phases : l'énergie non dépensée est perdue, inutile d'économiser."
    ],
    scene: {
      highlight: ["youBase"],
      tokens: [],
      runes: 2,
      energy: 2,
      essence: 1,
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "jouer",
    title: "Jouer des cartes",
    ref: "140",
    text: [
      "Les **unités** arrivent dans votre base, **épuisées** : elles attendront votre prochain tour pour agir (sauf Accélération).",
      "Les **équipements** arrivent préparés, dans votre base aussi.",
      "Les **sorts** font leur effet puis vont à la défausse. Pendant votre phase principale, jouez autant de cartes que vos runes le permettent."
    ],
    scene: {
      highlight: ["youBase"],
      tokens: [
        { id: "u1", zone: "youBase", side: "you", power: 3, exhausted: true, enter: true },
        { id: "u2", zone: "youBase", side: "you", power: 2, exhausted: true, enter: true }
      ],
      hand: 3,
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "deplacer",
    title: "Se déplacer vers un champ de bataille",
    ref: "144",
    text: [
      "Une unité préparée peut **s'épuiser pour se déplacer** : de votre base vers un champ de bataille, ou l'inverse.",
      "Plusieurs unités peuvent se déplacer **ensemble** vers la même destination.",
      "Arriver sur un champ de bataille adverse ou vide le rend **contesté** : une confrontation se prépare."
    ],
    scene: {
      highlight: ["bf1"],
      tokens: [
        { id: "u1", zone: "bf1", side: "you", power: 3, exhausted: true },
        { id: "u2", zone: "youBase", side: "you", power: 2 }
      ],
      arrow: { from: "youBase", to: "bf1" },
      contested: ["bf1"],
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "combat",
    title: "Le combat",
    ref: "459",
    text: [
      "Des unités ennemies sur le même champ de bataille ? **Combat.** Il commence par une **confrontation** : chacun peut jouer ses sorts Action ou Réaction, jusqu'à ce que les deux joueurs passent.",
      "Ensuite, chaque camp **additionne la puissance** de ses unités et l'inflige en dégâts au camp adverse.",
      "Une unité qui a subi des dégâts **égaux ou supérieurs à sa puissance** est éliminée."
    ],
    scene: {
      highlight: ["bf2"],
      tokens: [
        { id: "u1", zone: "bf2", side: "you", power: 3 },
        { id: "u2", zone: "bf2", side: "you", power: 2 },
        { id: "e1", zone: "bf2", side: "foe", power: 4 }
      ],
      contested: ["bf2"],
      clash: "bf2",
      score: { you: 1, foe: 0 }
    }
  },
  {
    key: "resolution",
    title: "L'issue du combat",
    ref: "466",
    text: [
      "Vos 3 + 2 = **5 dégâts** éliminent l'unité adverse de puissance 4. Ses 4 dégâts éliminent votre unité de puissance 3 (dégâts mortels), votre 2 survit.",
      "Après le combat, les unités survivantes sont **soignées**. Le camp qui reste seul **prend le contrôle** du champ de bataille.",
      "Prendre le contrôle = **conquête** = 1 point, si ce champ ne vous a pas déjà rapporté de point ce tour-ci."
    ],
    scene: {
      highlight: ["bf2"],
      tokens: [
        { id: "u1", zone: "bf2", side: "you", power: 3, dead: true },
        { id: "u2", zone: "bf2", side: "you", power: 2 },
        { id: "e1", zone: "bf2", side: "foe", power: 4, dead: true }
      ],
      control: { bf2: "you" },
      scorePulse: true,
      score: { you: 2, foe: 0 }
    }
  },
  {
    key: "fin-tour",
    title: "La fin du tour",
    ref: "317",
    text: [
      "Quand vous n'avez plus rien à faire, annoncez la fin de votre tour.",
      "Toutes les unités sont **soignées**, les effets « pendant ce tour » expirent, votre réserve runique se vide.",
      "C'est au joueur suivant. La partie continue, tour après tour, jusqu'à ce qu'un joueur atteigne **8 points**."
    ],
    scene: {
      highlight: ["foeBase"],
      tokens: [
        { id: "u2", zone: "bf2", side: "you", power: 2 },
        { id: "e2", zone: "foeBase", side: "foe", power: 3, enter: true }
      ],
      control: { bf2: "you" },
      score: { you: 2, foe: 0 }
    }
  }
]
