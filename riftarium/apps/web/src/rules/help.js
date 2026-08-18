/* Aide avancée : chaque fiche résume une mécanique d'après les règles officielles.
   `ref` renvoie à la section correspondante du lecteur officiel. */

export const CATEGORIES = [
  { key: "tour", label: "Tour & timing" },
  { key: "combat", label: "Combat" },
  { key: "points", label: "Champs de bataille & points" },
  { key: "cartes", label: "Cartes & ressources" },
  { key: "mots-cles", label: "Mots-clés" }
]

export const ENTRIES = [
  /* ---- Tour & timing ---- */
  {
    title: "Le déroulé complet d'un tour",
    category: "tour",
    ref: "301",
    summary: "Éveil, scores, canalisation, pioche, phase principale, fin de tour : l'ordre est rigide.",
    details: [
      "Début de tour : 1) Éveil — préparez tout ce que vous contrôlez. 2) Scores — vous marquez 1 point par champ de bataille contrôlé (occupation). 3) Canalisation — retournez 2 runes. 4) Pioche — piochez 1 carte.",
      "Phase principale : sans structure imposée. Jouez des cartes, déplacez des unités, activez des compétences, dans l'ordre de votre choix.",
      "Fin de tour : toutes les unités sont soignées, les effets « pendant ce tour » expirent, la réserve runique se vide, puis le joueur suivant commence."
    ]
  },
  {
    title: "La chaîne : qui résout quoi, et dans quel ordre",
    category: "tour",
    ref: "327",
    summary: "Les sorts et compétences s'empilent ; le dernier entré est résolu en premier.",
    details: [
      "Quand une carte ou une compétence est jouée, elle entre dans la chaîne. Les réponses (Réactions) s'empilent par-dessus et se résolvent avant ce qui était déjà là.",
      "Pendant qu'un objet de la chaîne se résout, rien d'autre ne peut se résoudre : terminez toutes ses instructions avant de passer au suivant."
    ]
  },
  {
    title: "Confrontation, focalisation et « passer »",
    category: "tour",
    ref: "341",
    summary: "Une fenêtre où chacun joue à tour de rôle ; deux passes consécutives la terminent.",
    details: [
      "Une confrontation s'ouvre quand un champ de bataille devient contesté. Le joueur qui a contesté reçoit la focalisation.",
      "Le joueur qui a la focalisation joue une carte ou compétence (Action/Réaction), ou passe. Après chaque chaîne résolue, la focalisation passe au joueur suivant.",
      "Si tous les joueurs passent successivement, la confrontation se termine : le combat continue, ou le contrôle est établi s'il n'y a pas de combat."
    ]
  },
  {
    title: "Action vs Réaction : quand puis-je jouer ?",
    category: "tour",
    ref: "153",
    summary: "Par défaut un sort se joue pendant votre tour, hors confrontation. Action et Réaction élargissent ça.",
    details: [
      "Sans mot-clé : uniquement pendant votre phase principale, en dehors des confrontations, quand la chaîne est vide.",
      "Action : aussi pendant les états ouverts des confrontations.",
      "Réaction : partout où une Action est permise, plus pendant les états fermés — donc en réponse à un sort adverse, avant sa résolution."
    ]
  },
  {
    title: "Exténuation : plus de cartes à piocher",
    category: "tour",
    ref: "431",
    summary: "Deck vide au moment de piocher : vous vous exténuez, l'adversaire peut en profiter.",
    details: [
      "Si vous devez piocher avec un deck principal vide, vous êtes exténué : votre défausse est remélangée pour former un nouveau deck, et un adversaire de votre choix gagne 1 point.",
      "Ensuite, vous piochez normalement. S'exténuer n'élimine pas de la partie, mais offrir des points se paie cher."
    ]
  },
  {
    title: "Nettoyages : quand le jeu « vérifie » l'état du plateau",
    category: "tour",
    ref: "318",
    summary: "Entre chaque action, le jeu élimine les unités mortes, met à jour le contrôle et vérifie la victoire.",
    details: [
      "Un nettoyage a lieu après chaque action ou résolution : unités avec dégâts mortels éliminées, contrôle des champs de bataille mis à jour, victoire vérifiée.",
      "C'est lors d'un nettoyage qu'un joueur à 8 points ou plus (et devant tous ses adversaires) gagne la partie."
    ]
  },

  /* ---- Combat ---- */
  {
    title: "Les trois étapes d'un combat",
    category: "combat",
    ref: "459",
    summary: "Confrontation, dégâts, résolution : le combat oppose exactement deux joueurs.",
    details: [
      "1. Confrontation de combat : l'attaquant (celui qui a contesté) a la focalisation ; chacun joue ses Actions/Réactions jusqu'à deux passes consécutives.",
      "2. Dégâts : chaque camp additionne la puissance de ses unités survivantes et attribue ce total en dégâts aux unités adverses. Tous les dégâts sont ensuite infligés simultanément.",
      "3. Résolution : nettoyage de combat (les survivants sont soignés, les attaquants sont rappelés si des défenseurs restent), puis le camp resté seul prend le contrôle."
    ]
  },
  {
    title: "Attribuer les dégâts de combat, dans les règles",
    category: "combat",
    ref: "465",
    summary: "On remplit unité par unité, jamais plus que le nécessaire, en respectant Tank et Arrière-ligne.",
    details: [
      "Une unité doit recevoir des dégâts mortels (≥ sa puissance) avant qu'on puisse en attribuer à la suivante.",
      "On ne peut pas attribuer plus que le minimum mortel à une unité, sauf s'il ne reste plus d'autre cible.",
      "Tank : doit recevoir les dégâts mortels en premier. Arrière-ligne : en dernier. Le surplus de dégâts, s'il ne suffit pas à tuer la dernière unité, est quand même infligé (elle sera soignée au nettoyage de combat)."
    ]
  },
  {
    title: "Attaquant rappelé, défenseur qui reste",
    category: "combat",
    ref: "466",
    summary: "Si les deux camps survivent, les attaquants rentrent à la base : défendre a un avantage.",
    details: [
      "Au nettoyage de combat, si des défenseurs sont encore présents, les unités attaquantes restantes sont rappelées à leur base.",
      "Il n'y a alors « aucun résultat » : personne ne conquiert, le défenseur garde le contrôle."
    ]
  },
  {
    title: "Combat à 3 ou 4 joueurs : qui peut intervenir ?",
    category: "combat",
    ref: "462",
    summary: "Un combat n'implique que deux joueurs ; les autres ne peuvent pas s'y inviter.",
    details: [
      "Un champ de bataille où un combat est préparé ou en cours est une destination interdite pour les unités des joueurs non impliqués.",
      "Si un effet forcerait une unité tierce à y être jouée, elle est jouée à la base de son contrôleur à la place."
    ]
  },

  /* ---- Champs de bataille & points ---- */
  {
    title: "Conquête vs occupation",
    category: "points",
    ref: "467",
    summary: "Conquérir = prendre le contrôle. Occuper = le garder jusqu'à votre phase de départ. 1 point chacun.",
    details: [
      "Conquête : vous prenez le contrôle d'un champ de bataille qui ne vous a pas encore rapporté de point ce tour-ci → 1 point, immédiatement.",
      "Occupation : au début de votre tour (étape des scores), chaque champ de bataille que vous contrôlez encore rapporte 1 point.",
      "Un même champ de bataille ne rapporte jamais plus d'un point par joueur et par tour."
    ]
  },
  {
    title: "Le dernier point est plus dur à marquer",
    category: "points",
    ref: "467",
    summary: "Pour conquérir le point de la victoire, il faut avoir marqué sur chaque champ de bataille ce tour-ci.",
    details: [
      "Quand une conquête vous amènerait à 8 points : elle ne compte que si vous avez marqué un point sur chaque champ de bataille pendant ce tour. Sinon, vous piochez une carte à la place.",
      "Les points gagnés par occupation ou par des effets de cartes ne subissent pas cette restriction — d'où l'intérêt de tenir ses positions."
    ]
  },
  {
    title: "Contrôle et statut « contesté »",
    category: "points",
    ref: "190",
    summary: "Le contrôle s'établit à la fin d'une confrontation ou d'un combat, pas dès qu'on arrive.",
    details: [
      "Arriver sur un champ de bataille qu'on ne contrôle pas le rend contesté. Le contrôle ne change qu'à l'issue de la confrontation ou du combat.",
      "Vous gardez le contrôle tant que vous avez des unités dessus. Si vous n'en avez plus, vous le perdez au prochain nettoyage.",
      "Un champ de bataille contrôlé mais vidé de ses unités reste à vous jusqu'à ce qu'un adversaire vienne le conquérir — ou que le nettoyage vous le retire faute d'unités."
    ]
  },
  {
    title: "Les compétences des champs de bataille",
    category: "points",
    ref: "190",
    summary: "Le contrôleur du champ de bataille contrôle ses compétences ; « vous » le désigne.",
    details: [
      "Contrôler un champ de bataille, c'est aussi contrôler ses compétences et prendre ses décisions.",
      "Non contrôlé : ses compétences sont gérées par le joueur du tour. « Vous » n'y désigne alors personne — ces instructions sont ignorées.",
      "Les compétences de conquête et d'occupation ne se déclenchent qu'au moment où un point y est marqué : au plus une fois par tour et par joueur."
    ]
  },
  {
    title: "La zone face cachée (mot-clé Caché)",
    category: "points",
    ref: "107",
    summary: "Chaque champ de bataille a un emplacement pour une carte face cachée, réservé à son contrôleur.",
    details: [
      "Une carte avec Caché peut être posée face cachée sur un champ de bataille que vous contrôlez (une seule carte par zone).",
      "Dès le tour suivant, elle gagne Réaction : vous pouvez la jouer au meilleur moment, en payant son coût.",
      "Si vous perdez le contrôle du champ de bataille, la carte cachée est retirée au prochain nettoyage."
    ]
  },

  /* ---- Cartes & ressources ---- */
  {
    title: "Construire un deck légal",
    category: "cartes",
    ref: "101",
    summary: "40 cartes minimum, 12 runes, 1 légende, 3 champs de bataille ; les domaines de la légende font loi.",
    details: [
      "Deck principal : 40 cartes minimum, dont votre champion élu. Maximum 3 exemplaires d'un même nom, et 3 cartes signatures (du tag de votre légende).",
      "Votre légende définit l'identité de domaine : chaque carte du deck doit rentrer dans ses domaines. Une carte bicolore exige les deux domaines.",
      "Deck de runes : exactement 12 runes, mêmes contraintes de domaine. Champs de bataille : pas de doublons de nom."
    ]
  },
  {
    title: "Énergie, essence runique et réserve",
    category: "cartes",
    ref: "160",
    summary: "Le chiffre du coût se paie en énergie, les symboles en essence du bon domaine. Rien ne se garde.",
    details: [
      "Une rune de base s'épuise pour +1 énergie, ou se recycle (retourne au deck de runes) pour 1 essence de son domaine. Ces compétences sont des Réactions : utilisables à tout moment où un coût doit être payé.",
      "La réserve runique se vide au début de chaque phase principale et à la fin de chaque tour : impossible de stocker.",
      "Recycler une rune est un vrai coût : elle quitte le plateau. Canaliser 2 runes par tour les remplace peu à peu."
    ]
  },
  {
    title: "Unités : arrivée, épuisement, dégâts",
    category: "cartes",
    ref: "140",
    summary: "Une unité entre en jeu épuisée dans votre base, et meurt si ses dégâts atteignent sa puissance.",
    details: [
      "Les unités arrivent épuisées (sauf Accélération) : pas de déplacement ni de coût « épuiser » avant votre prochaine phase d'éveil.",
      "Les dégâts marqués restent jusqu'à la fin du tour ou un nettoyage de combat, puis sont soignés. Dégâts ≥ puissance = élimination.",
      "Le déplacement standard : épuisez l'unité pour aller de la base vers un champ de bataille, ou revenir. Jamais de champ de bataille à champ de bataille (sauf Gank)."
    ]
  },
  {
    title: "Équipements et objets",
    category: "cartes",
    ref: "147",
    summary: "Ils entrent préparés, en base. Les objets s'attachent aux unités via Équiper ou Dégainer.",
    details: [
      "Un équipement se joue dans votre base et y reste ; seuls les équipements portés par une unité la suivent sur les champs de bataille.",
      "Équiper ([Coût] : équipez à une unité que vous contrôlez) s'active pendant votre phase principale. Dégainer équipe immédiatement, dès que l'objet est joué, et donne Réaction.",
      "L'objet ajoute son bonus de puissance et ses effets à l'unité équipée. Si elle quitte le plateau, l'objet retourne en base."
    ]
  },
  {
    title: "Le champion élu et la légende",
    category: "cartes",
    ref: "108",
    summary: "La légende reste en jeu toute la partie ; le champion élu attend dans sa zone d'être joué.",
    details: [
      "La légende n'est jamais mélangée au deck : elle est posée dès la mise en place, avec ses compétences utilisables selon leur texte.",
      "Le champion élu commence dans sa zone dédiée, visible de tous, et se joue comme une carte normale depuis cette zone.",
      "Une fois parti (éliminé, défaussé…), il ne revient pas dans sa zone : il suit les règles des cartes normales."
    ]
  },
  {
    title: "La Règle d'or et la Règle d'argent",
    category: "cartes",
    ref: "001",
    summary: "La carte bat le livre de règles ; les interdictions battent les autorisations.",
    details: [
      "Règle d'or : si une carte contredit les règles, la carte gagne.",
      "Règle d'argent : « carte » sur une carte = carte du deck principal. Les runes, légendes et champs de bataille n'en sont pas.",
      "Une interdiction (« ne peut pas ») l'emporte toujours sur une autorisation. Exécutez ce qui est possible, ignorez l'impossible."
    ]
  },

  /* ---- Mots-clés ---- */
  {
    title: "Accélération",
    category: "mots-cles",
    ref: "805",
    summary: "Payez [1] et une essence de plus quand vous la jouez : l'unité entre préparée.",
    details: [
      "« Quand vous me jouez, vous pouvez payer un coût supplémentaire de [1][C]. Si vous le faites, j'entre en jeu préparé. » L'unité peut agir immédiatement : se déplacer, payer des coûts d'épuisement."
    ]
  },
  {
    title: "Assaut & Bouclier",
    category: "mots-cles",
    ref: "807",
    summary: "+X puissance en attaque (Assaut) ou en défense (Bouclier).",
    details: [
      "Assaut X : « Tant que j'attaque, j'ai +X puissance. » Bouclier X : « Tant que je défends, j'ai +X puissance. »",
      "Actifs uniquement pendant un combat où l'unité a la désignation correspondante ; comptent dans le total de puissance du camp."
    ]
  },
  {
    title: "Tank & Arrière-ligne",
    category: "mots-cles",
    ref: "813",
    summary: "Ils dictent l'ordre d'attribution des dégâts de combat.",
    details: [
      "Tank : les dégâts mortels doivent lui être attribués avant toute autre unité du même camp sans Tank.",
      "Arrière-ligne : elle ne reçoit les dégâts mortels qu'en dernier.",
      "À priorité égale (deux Tanks), l'ordre est au choix du joueur qui attribue."
    ]
  },
  {
    title: "Gank & Embuscade",
    category: "mots-cles",
    ref: "810",
    summary: "Gank se déplace de champ en champ ; Embuscade se joue directement sur un champ de bataille.",
    details: [
      "Gank : le déplacement standard peut aller d'un champ de bataille à un autre, sans repasser par la base.",
      "Embuscade : l'unité peut être jouée sur un champ de bataille où vous contrôlez déjà des unités, et y gagne Réaction — jouable en pleine confrontation."
    ]
  },
  {
    title: "Agonie, Temporaire & Vision",
    category: "mots-cles",
    ref: "808",
    summary: "Trois déclencheurs : à l'élimination, au début de votre tour, quand la carte est jouée.",
    details: [
      "Agonie : « Lorsque je suis éliminé, [effet]. » Se déclenche aussi si l'élimination vient d'un combat.",
      "Temporaire : le permanent est éliminé au début de la phase de départ de son contrôleur, avant les points.",
      "Vision : « Lorsque ceci est joué, prédisez » — regardez le dessus de votre deck et choisissez de l'y laisser ou non."
    ]
  },
  {
    title: "Légion, Niveau & Amplifié",
    category: "mots-cles",
    ref: "812",
    summary: "Des bonus conditionnels : une autre carte jouée, de l'XP accumulée, ou l'état amplifié.",
    details: [
      "Légion : la carte gagne le texte associé si vous avez joué une autre carte ce tour-ci.",
      "Niveau N : tant que vous avez N XP ou plus, la carte gagne le texte associé. L'XP se gagne via des effets comme Chasse.",
      "Amplifié : tant que le permanent est amplifié (via sa compétence Amplification, une fois), il gagne le texte associé."
    ]
  },
  {
    title: "Protection, Répétition & Flux",
    category: "mots-cles",
    ref: "809",
    summary: "Taxer les sorts adverses, résoudre deux fois, rejouer depuis la défausse.",
    details: [
      "Protection X : les sorts et compétences adverses qui ciblent cette carte coûtent X essence de plus.",
      "Répétition : payez le coût supplémentaire pour exécuter les instructions du sort une seconde fois à la résolution.",
      "Flux : la carte peut être jouée depuis votre défausse pour son coût de flux, puis elle est bannie."
    ]
  },
  {
    title: "Chasse, Expert en armes & Unique",
    category: "mots-cles",
    ref: "820",
    summary: "Gagner de l'XP en marquant, équiper à prix réduit, limite de construction.",
    details: [
      "Chasse X : quand l'unité conquiert ou occupe, son contrôleur gagne X XP.",
      "Expert en armes : en jouant l'unité, équipez-lui un Objet que vous contrôlez en payant son coût d'Équiper réduit.",
      "Unique : contrainte de construction — un seul exemplaire dans le deck."
    ]
  }
]
