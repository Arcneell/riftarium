/* Aide avancée : un sujet = une page complète.
   `sections` référence les sections des règles officielles (rules-fr.json) qui
   sont affichées en intégralité au bas de chaque page. `examples` montre de
   vraies cartes (visuels servis par le CDN officiel Riot). */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live"
const img = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=360&accountingTag=RB`

export const CATEGORIES = [
  { key: "tour", label: "Tour & timing" },
  { key: "combat", label: "Combat" },
  { key: "points", label: "Champs de bataille & points" },
  { key: "cartes", label: "Cartes & ressources" },
  { key: "mots-cles", label: "Mots-clés" }
]

export const TOPICS = [
  /* ================= Tour & timing ================= */
  {
    slug: "deroulement-du-tour",
    title: "Le déroulement du tour",
    category: "tour",
    summary: "Éveil, scores, canalisation, pioche, phase principale, fin de tour : l'ordre exact.",
    details: [
      "Début de tour, quatre phases automatiques : **éveil** (préparez tout ce que vous contrôlez), **phase de départ** avec l'étape des scores (1 point par champ de bataille contrôlé), **canalisation** (2 runes), **pioche** (1 carte).",
      "**Phase principale** : sans structure imposée — jouez des cartes, déplacez des unités, activez des compétences, dans l'ordre de votre choix.",
      "**Fin de tour** : toutes les unités sont soignées, les effets « pendant ce tour » expirent, la réserve runique se vide."
    ],
    cases: [
      {
        q: "Je contrôle un champ de bataille conquis au tour précédent. Quand marque-t-il ?",
        a: "À l'étape des scores de votre phase de départ : +1 point d'occupation, avant la canalisation et la pioche."
      },
      {
        q: "Puis-je jouer une carte pendant la phase d'éveil ou la canalisation ?",
        a: "Non. Les cartes se jouent en phase principale (ou pendant les confrontations pour les sorts Action/Réaction)."
      },
      {
        q: "Mes unités blessées gardent-elles leurs dégâts d'un tour à l'autre ?",
        a: "Non : toutes les unités sont soignées à la fin de chaque tour, et après chaque combat lors du nettoyage de combat."
      }
    ],
    sections: ["301", "315", "316", "317"]
  },
  {
    slug: "la-chaine",
    title: "La chaîne",
    category: "tour",
    summary: "Les sorts et compétences s'empilent ; le dernier entré se résout en premier.",
    details: [
      "Quand une carte ou une compétence est jouée, elle entre dans la **chaîne**. Les réponses s'empilent par-dessus et se résolvent avant ce qui était déjà là.",
      "Pendant qu'un objet de la chaîne se résout, rien d'autre ne peut se résoudre : terminez toutes ses instructions avant de passer au suivant.",
      "Les sorts **Réaction** peuvent être joués pendant les états fermés — donc en réponse à un sort adverse, avant sa résolution."
    ],
    cases: [
      {
        q: "L'adversaire joue un sort qui élimine mon unité. Puis-je réagir ?",
        a: "Oui, avec un sort Réaction (ou une compétence Réaction) : il s'empile au-dessus et se résout avant. Un sort Action ne suffit pas pendant un état fermé."
      },
      {
        q: "Un sort en cours de résolution déclenche une compétence. Quand se résout-elle ?",
        a: "Après la résolution complète du sort : on termine toutes ses instructions, puis les déclenchements sont ajoutés à la chaîne."
      }
    ],
    sections: ["327", "332"]
  },
  {
    slug: "confrontation-et-focalisation",
    title: "Confrontation et focalisation",
    category: "tour",
    summary: "Une fenêtre où chacun joue à tour de rôle ; deux passes consécutives la terminent.",
    details: [
      "Une **confrontation** s'ouvre quand un champ de bataille devient contesté. Le joueur qui a contesté reçoit la **focalisation**.",
      "Le joueur qui a la focalisation joue une carte ou compétence (Action/Réaction), ou **passe**. Après chaque chaîne résolue, la focalisation passe au joueur suivant.",
      "Si tous les joueurs passent successivement, la confrontation se termine : combat s'il y a des unités des deux camps, sinon prise de contrôle."
    ],
    cases: [
      {
        q: "J'ai contesté un champ vide. Que se passe-t-il ?",
        a: "Une confrontation sans combat : si à la fin vous êtes le seul à y avoir des unités, vous prenez le contrôle — conquête si ce champ ne vous a pas déjà rapporté de point ce tour."
      },
      {
        q: "L'adversaire déplace une unité sur le champ pendant la confrontation sans combat. Et alors ?",
        a: "La confrontation deviendra une confrontation de combat au prochain nettoyage : un combat s'y engagera."
      }
    ],
    sections: ["341", "311"]
  },
  {
    slug: "extenuation",
    title: "L'exténuation (deck vide)",
    category: "tour",
    summary: "Piocher deck vide : la défausse redevient un deck, l'adversaire gagne 1 point.",
    details: [
      "Si vous devez piocher alors que votre deck principal est vide, vous êtes **exténué** : votre défausse est remélangée pour former un nouveau deck, et **un adversaire de votre choix gagne 1 point**.",
      "Ensuite, vous piochez normalement. S'exténuer n'élimine pas de la partie, mais chaque exténuation offre un point."
    ],
    cases: [
      {
        q: "Un effet me fait piocher 3 cartes et mon deck n'en a qu'une. Combien d'exténuations ?",
        a: "Vous piochez la dernière carte, puis chaque pioche impossible déclenche le processus : remélange et point offert, autant de fois que nécessaire pour finir les pioches."
      }
    ],
    sections: ["431", "413"]
  },
  {
    slug: "nettoyages",
    title: "Les nettoyages",
    category: "tour",
    summary: "Entre chaque action, le jeu élimine les unités mortes, met à jour le contrôle, vérifie la victoire.",
    details: [
      "Un **nettoyage** a lieu après chaque action ou résolution : unités avec dégâts mortels éliminées, contrôle des champs de bataille mis à jour, victoire vérifiée.",
      "C'est lors d'un nettoyage qu'un joueur à 8 points ou plus (et devant tous ses adversaires) gagne la partie.",
      "Le **nettoyage de combat** ajoute deux étapes : soigner toutes les unités, et rappeler les attaquants si des défenseurs restent."
    ],
    cases: [
      {
        q: "Mon unité et celle de l'adversaire atteignent des dégâts mortels en même temps. Qui meurt ?",
        a: "Les deux : le nettoyage élimine simultanément toutes les unités dont les dégâts égalent ou dépassent la puissance."
      }
    ],
    sections: ["318"]
  },

  /* ================= Combat ================= */
  {
    slug: "etapes-du-combat",
    title: "Les trois étapes du combat",
    category: "combat",
    summary: "Confrontation, dégâts, résolution — un combat oppose exactement deux joueurs.",
    details: [
      "**1. Confrontation de combat** : l'attaquant (celui qui a contesté) a la focalisation ; chacun joue ses Actions/Réactions jusqu'à deux passes consécutives.",
      "**2. Dégâts** : chaque camp additionne la puissance de ses unités survivantes et attribue ce total aux unités adverses. Tout est infligé simultanément.",
      "**3. Résolution** : nettoyage de combat (soins, rappel éventuel des attaquants), puis le camp resté seul prend le contrôle — conquête si applicable."
    ],
    cases: [
      {
        q: "Qui est l'attaquant si une confrontation était déjà en cours quand le combat démarre ?",
        a: "L'attaquant reste le joueur dont les unités ont appliqué le statut contesté au champ de bataille ; la focalisation est conservée par celui qui l'avait."
      },
      {
        q: "Une unité arrive sur le champ en plein combat. Est-elle attaquante ou défenseuse ?",
        a: "Elle reçoit la désignation de son camp (attaquant ou défenseur) au nettoyage qui suit son arrivée."
      }
    ],
    sections: ["459", "464", "465", "466"]
  },
  {
    slug: "attribution-des-degats",
    title: "Attribuer les dégâts de combat",
    category: "combat",
    summary: "Dégâts mortels unité par unité, jamais plus que nécessaire, Tank d'abord, Arrière-ligne en dernier.",
    details: [
      "Une unité doit recevoir des **dégâts mortels** (≥ sa puissance, en comptant les dégâts déjà marqués) avant qu'on puisse en attribuer à la suivante.",
      "On ne peut pas attribuer plus que le minimum mortel à une unité — sauf s'il ne reste plus aucune autre cible.",
      "**Tank** doit recevoir les dégâts mortels en premier ; **Arrière-ligne** en dernier. À priorité égale, l'ordre est au choix du joueur qui attribue."
    ],
    cases: [
      {
        q: "L'adversaire a un Tank de 5 et je n'ai que 3 de puissance totale. Puis-je viser l'autre unité ?",
        a: "Non. Tant que le Tank n'a pas reçu de dégâts mortels, aucune autre unité ne peut en recevoir : vos 3 dégâts partent sur le Tank (et il survivra)."
      },
      {
        q: "Deux unités adverses ont Tank. Laquelle en premier ?",
        a: "Au choix du joueur qui attribue : à priorité égale, l'ordre est libre."
      },
      {
        q: "Une unité déjà blessée de 2 (puissance 4) : combien pour la finir ?",
        a: "2 suffisent — les dégâts mortels se calculent sur le total marqué, pas sur les seuls dégâts de combat."
      }
    ],
    sections: ["465", "417"]
  },
  {
    slug: "rappel-des-attaquants",
    title: "Le rappel des attaquants",
    category: "combat",
    summary: "Si les deux camps survivent, les attaquants rentrent à la base : défendre a l'avantage.",
    details: [
      "Au nettoyage de combat, si des défenseurs sont encore présents, les unités attaquantes restantes sont **rappelées** à leur base.",
      "Il n'y a alors « aucun résultat » : personne ne conquiert, le défenseur garde le contrôle."
    ],
    cases: [
      {
        q: "J'attaque avec 3 de puissance contre 4 : que se passe-t-il si personne ne meurt ?",
        a: "Vos unités survivantes sont rappelées à votre base (épuisées), le défenseur garde son champ. L'attaque n'a rien rapporté."
      }
    ],
    sections: ["466", "454"]
  },
  {
    slug: "combat-multijoueur",
    title: "Combat à 3 ou 4 joueurs",
    category: "combat",
    summary: "Un combat n'implique que deux joueurs ; les autres ne peuvent pas s'y inviter.",
    details: [
      "Un champ de bataille où un combat est préparé ou en cours est une **destination interdite** pour les unités des joueurs non impliqués.",
      "Si un effet forçait une unité tierce à y être jouée, elle est jouée dans la base de son contrôleur à la place."
    ],
    cases: [
      {
        q: "Deux adversaires se battent sur un champ. Puis-je y envoyer une unité pour ramasser la conquête ?",
        a: "Non : tant que le combat est préparé ou en cours, ce champ est une destination non valide pour vos déplacements."
      }
    ],
    sections: ["462", "447"]
  },

  /* ================= Champs de bataille & points ================= */
  {
    slug: "conquete-et-occupation",
    title: "Conquête et occupation",
    category: "points",
    summary: "Conquérir = prendre le contrôle (+1 immédiat). Occuper = le garder au début de votre tour (+1).",
    details: [
      "**Conquête** : vous prenez le contrôle d'un champ de bataille qui ne vous a pas encore rapporté de point ce tour-ci → 1 point, immédiatement.",
      "**Occupation** : au début de votre tour (étape des scores), chaque champ de bataille que vous contrôlez encore rapporte 1 point.",
      "Un même champ de bataille ne rapporte jamais plus d'un point par joueur et par tour."
    ],
    cases: [
      {
        q: "Je conquiers un champ, je le perds, je le reprends dans le même tour. Deux points ?",
        a: "Non : un champ ne peut vous rapporter qu'un point par tour, quelle que soit la façon."
      },
      {
        q: "Je conquiers un champ pendant le tour de l'adversaire (grâce à un effet). Point ?",
        a: "Oui : la conquête marque au moment de la prise de contrôle, peu importe le joueur du tour — dans la limite d'un point par champ et par tour."
      }
    ],
    sections: ["467", "193"]
  },
  {
    slug: "dernier-point",
    title: "Le point de la victoire",
    category: "points",
    summary: "Finir par conquête exige d'avoir marqué sur chaque champ ce tour-là ; l'occupation n'a pas cette limite.",
    details: [
      "Quand une **conquête** vous amènerait au score de la victoire : elle ne compte que si vous avez marqué un point sur **chaque** champ de bataille pendant ce tour. Sinon, vous **piochez une carte** à la place.",
      "Les points gagnés par **occupation** ou par des effets de cartes ne subissent pas cette restriction."
    ],
    cases: [
      {
        q: "7 points, je conquiers un seul champ ce tour : victoire ?",
        a: "Non — en duel il faut avoir marqué sur les 2 champs ce tour-là pour prendre le dernier point par conquête. Vous piochez une carte à la place."
      },
      {
        q: "7 points, j'occupe mon champ au début de mon tour : victoire ?",
        a: "Oui : l'occupation n'a aucune restriction. 8 points, la partie se termine au nettoyage."
      }
    ],
    sections: ["467", "193"]
  },
  {
    slug: "controle-et-conteste",
    title: "Contrôle et statut contesté",
    category: "points",
    summary: "Le contrôle s'établit à l'issue d'une confrontation ou d'un combat, pas dès qu'on arrive.",
    details: [
      "Arriver sur un champ de bataille qu'on ne contrôle pas le rend **contesté**. Le contrôle ne change qu'à l'issue de la confrontation ou du combat.",
      "Vous gardez le contrôle tant que vous avez des unités dessus. Sans unités, vous le perdez au prochain nettoyage.",
      "Un champ contrôlé mais vide reste à vous jusqu'au nettoyage — l'adversaire peut venir le conquérir sans combat."
    ],
    cases: [
      {
        q: "Ma dernière unité du champ meurt pendant mon tour. Je perds le contrôle tout de suite ?",
        a: "Au prochain nettoyage (hors combat/confrontation en cours). D'ici là, les compétences du champ restent à vous."
      }
    ],
    sections: ["190", "188"]
  },
  {
    slug: "competences-des-champs",
    title: "Les compétences des champs de bataille",
    category: "points",
    summary: "Le contrôleur du champ contrôle ses compétences ; « vous » le désigne.",
    details: [
      "Contrôler un champ de bataille, c'est contrôler ses compétences et prendre ses décisions.",
      "Champ non contrôlé : ses compétences sont gérées par le joueur du tour ; « vous » n'y désigne personne, ces instructions sont ignorées.",
      "Les compétences de **conquête** et d'**occupation** ne se déclenchent qu'au moment où un point y est marqué — au plus une fois par tour et par joueur."
    ],
    cases: [
      {
        q: "Le champ dit « quand vous conquérez ici, piochez 1 ». Je le conquiers une 2e fois dans le tour ?",
        a: "Pas de déclenchement : la compétence ne s'active que quand un point est marqué, donc une fois par tour maximum."
      }
    ],
    sections: ["190", "169"]
  },

  /* ================= Cartes & ressources ================= */
  {
    slug: "construire-un-deck",
    title: "Construire un deck légal",
    category: "cartes",
    summary: "40 cartes minimum, 12 runes, 1 légende, 3 champs de bataille ; les domaines de la légende font loi.",
    details: [
      "Deck principal : **40 cartes minimum**, dont votre champion élu. Maximum **3 exemplaires** d'un même nom, et 3 cartes signatures (du tag de votre légende).",
      "Votre légende définit l'**identité de domaine** : chaque carte du deck doit y rentrer. Une carte bicolore exige les deux domaines.",
      "Deck de runes : **exactement 12 runes**, mêmes contraintes de domaine. Champs de bataille : 3, sans doublon de nom."
    ],
    cases: [
      {
        q: "Ma légende est Fureur/Chaos. Puis-je jouer une carte Fureur/Calme ?",
        a: "Non : une carte multi-domaines exige que TOUS ses domaines soient dans l'identité de votre légende."
      },
      {
        q: "Puis-je mettre 3 champs de bataille identiques ?",
        a: "Non : pas de doublons de nom parmi vos champs de bataille."
      }
    ],
    sections: ["101"]
  },
  {
    slug: "energie-et-essence",
    title: "Énergie, essence et réserve runique",
    category: "cartes",
    summary: "Épuiser une rune : +1 énergie. La recycler : +1 essence, elle passe sous le deck de runes.",
    details: [
      "Une rune de base s'**épuise** pour +1 énergie, ou se **recycle** (placée sous le deck de runes, règle 416) pour 1 essence de son domaine. Ces compétences sont des **Réactions** : utilisables à tout moment où un coût se paie.",
      "La **réserve runique** se vide au début de chaque phase principale et à la fin de chaque tour : impossible de stocker.",
      "Les runes canalisées restent en zone de runes de tour en tour — le total grandit de 2 chaque tour."
    ],
    cases: [
      {
        q: "Puis-je recycler une rune épuisée ?",
        a: "Oui : recycler n'exige pas que la rune soit préparée — c'est un coût différent de l'épuisement."
      },
      {
        q: "Il me reste 2 énergies non dépensées en fin de phase. Je les garde ?",
        a: "Non : la réserve runique se vide, tout ce qui n'est pas dépensé est perdu."
      },
      {
        q: "L'essence universelle, ça existe ?",
        a: "Oui, certaines essences sont universelles et paient n'importe quel symbole de domaine (règle 163.2.b)."
      }
    ],
    sections: ["160", "164", "165", "416"]
  },
  {
    slug: "unites",
    title: "Les unités : arrivée, déplacement, dégâts",
    category: "cartes",
    summary: "Une unité entre épuisée dans votre base ; elle meurt si ses dégâts atteignent sa puissance.",
    details: [
      "Les unités arrivent **épuisées** dans votre base (sauf Accélération, ou Embuscade pour l'emplacement).",
      "Le **déplacement standard** : épuisez l'unité pour aller de la base vers un champ de bataille, ou en revenir. Jamais de champ à champ (sauf Gank). Plusieurs unités peuvent partir ensemble vers la même destination.",
      "Les dégâts restent marqués jusqu'à la fin du tour ou un nettoyage de combat, puis sont soignés. Dégâts ≥ puissance = élimination au nettoyage."
    ],
    cases: [
      {
        q: "Puis-je déplacer une unité pendant une confrontation ?",
        a: "Non : le déplacement standard est interdit pendant les confrontations et les combats, et pendant un état fermé."
      },
      {
        q: "Deux unités partent de deux endroits différents vers le même champ : un seul déplacement ?",
        a: "Oui : le déplacement simultané exige la même destination, pas le même point de départ."
      }
    ],
    sections: ["140", "144", "445"]
  },
  {
    slug: "equipements-et-objets",
    title: "Équipements et objets",
    category: "cartes",
    summary: "Ils entrent préparés, en base. Les objets s'attachent aux unités via Équiper ou Dégainer.",
    details: [
      "Un équipement se joue dans votre base et y reste ; seuls les équipements portés par une unité la suivent sur les champs de bataille.",
      "**Équiper** ([Coût] : équipez à une unité que vous contrôlez) s'active pendant votre phase principale. **Dégainer** équipe immédiatement quand l'objet est joué, avec les permissions d'une Réaction.",
      "L'objet ajoute son bonus de puissance et ses effets à l'unité équipée. Si un équipement non porté se retrouve sur un champ, il est rappelé à la base au nettoyage."
    ],
    cases: [
      {
        q: "Mon unité équipée meurt. L'objet aussi ?",
        a: "Non : l'équipement se retrouve non porté ; s'il est sur un champ de bataille, il est rappelé à votre base au nettoyage."
      },
      {
        q: "Puis-je équiper un objet à une unité adverse ?",
        a: "Non : Équiper cible une unité que VOUS contrôlez."
      }
    ],
    sections: ["147", "434", "435"],
    examples: [
      { id: "sfd-002-221", name: "Armed Assailant", img: img("1debdef1d45f7b2a452951db39674aeb01a8dc2b-744x1039.png") }
    ]
  },
  {
    slug: "champion-elu-et-legende",
    title: "Champion élu et légende",
    category: "cartes",
    summary: "La légende reste en jeu toute la partie ; le champion élu attend dans sa zone d'être joué.",
    details: [
      "La **légende** n'est jamais mélangée au deck : posée dès la mise en place, ses compétences (passives, déclenchées ou activées) fonctionnent toute la partie. Elle ne peut être ni éliminée ni déplacée.",
      "Le **champion élu** commence dans sa zone dédiée, visible de tous, et se joue comme une carte normale depuis cette zone.",
      "Une fois parti (éliminé, défaussé…), il ne revient pas dans sa zone : il suit les règles des cartes normales."
    ],
    cases: [
      {
        q: "Mon champion élu est éliminé. Puis-je le rejouer depuis sa zone ?",
        a: "Non : il va à la défausse comme n'importe quelle unité. La zone de champion ne sert qu'au départ."
      },
      {
        q: "La compétence de ma légende coûte « [E] : effet ». Quand puis-je l'activer ?",
        a: "Comme une compétence activée : pendant votre phase principale, dans un état ouvert, hors confrontation — sauf si elle porte Action ou Réaction."
      }
    ],
    sections: ["108", "173", "376"]
  },
  {
    slug: "regle-d-or",
    title: "Règle d'or et règle d'argent",
    category: "cartes",
    summary: "La carte bat le livre de règles ; les interdictions battent les autorisations.",
    details: [
      "**Règle d'or** : si une carte contredit les règles, la carte gagne.",
      "**Règle d'argent** : dans un texte de carte, « carte » désigne une carte du deck principal — les runes, légendes et champs de bataille n'en sont pas.",
      "Une interdiction (« ne peut pas ») l'emporte toujours sur une autorisation. Exécutez ce qui est possible, ignorez l'impossible."
    ],
    cases: [
      {
        q: "Un effet dit « détruisez une carte » : puis-je viser une rune ?",
        a: "Non : dans les textes de cartes, « carte » = carte du deck principal. Les runes n'en font pas partie."
      }
    ],
    sections: ["001", "050"]
  },

  /* ================= Mots-clés ================= */
  {
    slug: "acceleration",
    title: "Accélération",
    category: "mots-cles",
    summary: "Coût additionnel de 1 énergie + 1 essence : l'unité entre en jeu préparée.",
    details: [
      "« Quand vous me jouez, vous pouvez payer un coût supplémentaire de [1][essence]. Si vous le faites, j'entre en jeu préparé. »",
      "Le choix se fait au moment de jouer la carte ; le coût s'ajoute au coût normal.",
      "Une unité entrée préparée peut immédiatement se déplacer ou payer des coûts d'épuisement."
    ],
    cases: [
      {
        q: "Puis-je payer l'Accélération plus tard dans le tour ?",
        a: "Non : c'est un coût additionnel payé au moment où vous jouez l'unité, ou jamais."
      },
      {
        q: "Accélération + Embuscade : l'unité peut-elle arriver préparée sur un champ de bataille ?",
        a: "Oui, si vous payez les deux conditions : Embuscade autorise l'emplacement, l'Accélération l'état préparé."
      }
    ],
    sections: ["805"],
    examples: [
      { id: "ogn-010-298", name: "Legion Rearguard", img: img("aedece01c7792c689050460db1670e6b9b15b61f-744x1039.png") }
    ]
  },
  {
    slug: "action",
    title: "Action",
    category: "mots-cles",
    summary: "Jouable pendant votre tour ET pendant les états ouverts des confrontations.",
    details: [
      "Un sort sans mot-clé ne se joue que pendant votre phase principale, hors confrontation, chaîne vide.",
      "**Action** élargit : aussi jouable dans les états ouverts des confrontations — y compris pendant le tour adverse si une confrontation s'y ouvre."
    ],
    cases: [
      {
        q: "L'adversaire m'attaque pendant son tour. Puis-je jouer un sort Action ?",
        a: "Oui, pendant la confrontation de combat, quand vous avez la focalisation et que l'état est ouvert."
      }
    ],
    sections: ["806", "153"],
    examples: [{ id: "ogn-004-298", name: "Cleave", img: img("95d476a1e88ff547fb846149619177bc7e3cea9f-744x1039.png") }]
  },
  {
    slug: "reaction",
    title: "Réaction",
    category: "mots-cles",
    summary: "Tout ce que permet Action, plus les états fermés : répondre avant la résolution adverse.",
    details: [
      "**Réaction** = toutes les permissions d'Action, plus les **états fermés** : jouable en réponse à un sort ou une compétence, avant sa résolution.",
      "Un sort Réaction se résout donc avant les objets déjà dans la chaîne.",
      "Les compétences de runes (« Ajoutez... ») sont des Réactions : utilisables à l'instant précis où un coût doit être payé."
    ],
    cases: [
      {
        q: "L'adversaire cible mon unité avec un sort d'élimination. Ma Réaction la sauve-t-elle ?",
        a: "Si votre Réaction la retire du plateau ou invalide la cible avant la résolution, le sort adverse échoue sur cette cible."
      }
    ],
    sections: ["813", "153"],
    examples: [
      { id: "ogn-033-298", name: "Shakedown", img: img("ab71d92c94bf609e2fa6efc8fec06fe1e8b10108-744x1039.png") }
    ]
  },
  {
    slug: "assaut",
    title: "Assaut",
    category: "mots-cles",
    summary: "+X puissance tant que l'unité attaque.",
    details: [
      "« Tant que j'attaque, j'ai +X puissance. »",
      "Actif uniquement pendant un combat où l'unité a la désignation d'attaquant ; compte dans le total de puissance du camp."
    ],
    cases: [
      {
        q: "Assaut compte-t-il quand je défends mon champ de bataille ?",
        a: "Non : le bonus n'existe que tant que l'unité est attaquante."
      }
    ],
    sections: ["807"],
    examples: [
      {
        id: "ogn-003-298",
        name: "Chemtech Enforcer",
        img: img("19dcf211457d9c9c6e9ea0cd32af76c2c92a3160-744x1039.png")
      }
    ]
  },
  {
    slug: "bouclier",
    title: "Bouclier",
    category: "mots-cles",
    summary: "+X puissance tant que l'unité défend.",
    details: [
      "« Tant que je défends, j'ai +X puissance. »",
      "Actif dès que l'unité a la désignation de défenseur — il augmente aussi le seuil de dégâts mortels pendant le combat."
    ],
    cases: [
      {
        q: "Bouclier 1 sur une unité de puissance 3 : combien de dégâts pour la tuer en combat ?",
        a: "4 en défense : la puissance effective monte à 4, donc le seuil de dégâts mortels aussi."
      }
    ],
    sections: ["814"],
    examples: [
      { id: "ogn-052-298", name: "Stalwart Poro", img: img("c4a5d7178e783c3975749271b6df333a82a2328a-744x1039.png") }
    ]
  },
  {
    slug: "tank",
    title: "Tank",
    category: "mots-cles",
    summary: "Les dégâts de combat mortels doivent lui être attribués en premier.",
    details: [
      "Les dégâts mortels doivent être attribués au Tank avant toute autre unité du même camp sans Tank, pendant l'étape des dégâts de combat.",
      "Ne s'applique qu'aux dégâts de combat — un sort peut viser qui il veut."
    ],
    cases: [
      {
        q: "Puis-je « sauter » un Tank que je ne peux pas tuer ?",
        a: "Non : sans dégâts mortels attribués au Tank, aucune autre unité ne peut en recevoir. Vos dégâts partent dessus, même en pure perte."
      },
      {
        q: "Tank protège-t-il contre un sort de dégâts ?",
        a: "Non : Tank ne contraint que l'attribution des dégâts de combat."
      }
    ],
    sections: ["815", "465"],
    examples: [
      { id: "ogn-054-298", name: "Sunlit Guardian", img: img("28bce7a662b9008f65565300f828d98790a641e1-744x1039.png") }
    ]
  },
  {
    slug: "arriere-ligne",
    title: "Arrière-ligne",
    category: "mots-cles",
    summary: "Les dégâts de combat mortels lui sont attribués en dernier.",
    details: [
      "L'inverse de Tank : cette unité ne reçoit les dégâts mortels qu'après toutes les autres unités du même camp sans Arrière-ligne.",
      "À priorité égale (plusieurs Arrière-lignes), l'ordre est au choix du joueur qui attribue."
    ],
    cases: [
      {
        q: "Arrière-ligne + Tank sur la même unité : que se passe-t-il ?",
        a: "Exigences exclusives : le joueur qui attribue choisit UNE des deux compétences à appliquer (règle 465.2.c.8)."
      }
    ],
    sections: ["826", "465"],
    examples: [
      {
        id: "unl-043-219",
        name: "Enthusiastic Promoter",
        img: img("c03bdc371440cbf6de773b0b39010808bfdecea1-744x1039.png")
      }
    ]
  },
  {
    slug: "gank",
    title: "Gank",
    category: "mots-cles",
    summary: "Le déplacement standard peut aller d'un champ de bataille à un autre.",
    details: [
      "Normalement, une unité se déplace base ↔ champ de bataille. Avec **Gank**, son déplacement standard peut aussi aller de champ à champ.",
      "Les restrictions habituelles s'appliquent : pas pendant une confrontation, pas vers un champ où un combat de deux autres joueurs se prépare."
    ],
    cases: [
      {
        q: "Mon unité Gank est sur un champ contesté. Peut-elle fuir vers l'autre champ ?",
        a: "Non si une confrontation ou un combat y est en cours : le déplacement standard est interdit pendant ces phases."
      }
    ],
    sections: ["810", "144"],
    examples: [
      { id: "ogn-019-298", name: "Raging Soul", img: img("037647d0decc94ff4a5d53b11cf36afe9d849533-744x1039.png") }
    ]
  },
  {
    slug: "embuscade",
    title: "Embuscade",
    category: "mots-cles",
    summary: "Jouable directement sur un champ de bataille où vous avez des unités, avec Réaction.",
    details: [
      "« Je peux être joué sur un champ de bataille où vous contrôlez des unités » — au lieu de la base.",
      "Jouée ainsi, l'unité gagne les permissions d'une **Réaction** : elle peut surgir en pleine confrontation, même pendant le tour adverse."
    ],
    cases: [
      {
        q: "Puis-je jouer une unité Embuscade au milieu d'un combat pour ajouter sa puissance ?",
        a: "Oui, si vous contrôlez déjà des unités sur ce champ : elle arrive (épuisée sauf Accélération payée) et comptera dans les dégâts si elle est là à l'étape des dégâts."
      }
    ],
    sections: ["822"],
    examples: [
      { id: "unl-002-219", name: "Inferna", img: img("5db9d66fc22887e8686a13ffdfe480106cbd3b35-744x1039.png") }
    ]
  },
  {
    slug: "cache",
    title: "Caché",
    category: "mots-cles",
    summary: "Posez la carte face cachée sur un champ que vous contrôlez ; jouable en Réaction dès le tour suivant.",
    details: [
      "Payez [le coût Caché] pour placer la carte **face cachée** sur un champ de bataille que vous contrôlez (une seule carte par zone de face cachée).",
      "À partir du tour suivant, elle gagne **Réaction** : jouez-la au meilleur moment en payant son coût.",
      "Si vous perdez le contrôle du champ, la carte cachée est retirée au prochain nettoyage."
    ],
    cases: [
      {
        q: "L'adversaire peut-il regarder ma carte cachée ?",
        a: "Non : la zone est publique, la carte est privée. Il sait qu'il y a une carte, pas laquelle."
      },
      {
        q: "Je perds le champ puis le reprends : ma carte cachée est-elle encore là ?",
        a: "Non, si un nettoyage a eu lieu entre-temps : elle est retirée dès que le contrôleur du champ ne correspond plus."
      }
    ],
    sections: ["811", "107"],
    examples: [
      { id: "ogn-018-298", name: "Noxus Saboteur", img: img("b78f0c822cb984db24ac3f1956cc8c10f8f88b22-744x1039.png") }
    ]
  },
  {
    slug: "agonie",
    title: "Agonie",
    category: "mots-cles",
    summary: "« Lorsque je suis éliminé, [effet]. »",
    details: [
      "Compétence déclenchée à l'élimination du permanent, quelle que soit la cause : combat, sort, coût.",
      "L'effet se résout via la chaîne après le nettoyage qui a constaté l'élimination."
    ],
    cases: [
      {
        q: "Mon unité Agonie meurt pendant l'étape des dégâts de combat. L'effet part quand ?",
        a: "Après le nettoyage de combat qui l'élimine — l'effet s'ajoute à la chaîne et se résout avant la suite de la résolution du combat."
      }
    ],
    sections: ["808"],
    examples: [
      { id: "ogn-075-298", name: "Tasty Faefolk", img: img("65f69ca9a1087deb12e91fb6fdee7b6efd0c088f-744x1039.png") }
    ]
  },
  {
    slug: "temporaire",
    title: "Temporaire",
    category: "mots-cles",
    summary: "Éliminé au début de la phase de départ de son contrôleur, avant les points.",
    details: [
      "« Au début de la phase de départ du joueur qui contrôle ce permanent, avant d'octroyer les points, éliminez cet élément. »",
      "Conséquence clé : une unité Temporaire seule sur un champ disparaît AVANT l'étape des scores — pas de point d'occupation grâce à elle."
    ],
    cases: [
      {
        q: "Ma création Temporaire tient un champ de bataille. Vais-je marquer l'occupation ?",
        a: "Non : elle est éliminée avant l'octroi des points. Le champ reste peut-être à vous, mais vide — et prenable."
      }
    ],
    sections: ["816"],
    examples: [
      { id: "ogn-069-298", name: "Last Stand", img: img("9062d372d299c5c6a0c679f0ff07ba71590ca5f1-744x1039.png") }
    ]
  },
  {
    slug: "vision",
    title: "Vision",
    category: "mots-cles",
    summary: "« Lorsque ceci est joué, prédisez. »",
    details: [
      "**Prédire** : regardez la carte du dessus de votre deck principal ; laissez-la ou placez-la dessous.",
      "Vision se déclenche quand la carte est jouée — avant sa résolution complète."
    ],
    cases: [
      {
        q: "Vision se déclenche-t-il si la carte est contrée ?",
        a: "Le déclencheur « lorsque ceci est joué » part au moment où la carte est jouée : la prédiction a lieu même si la carte est ensuite contrée."
      }
    ],
    sections: ["817", "436"],
    examples: [
      { id: "ogn-086-298", name: "Jeweled Colossus", img: img("775bea14038165fd9feb15c796ed84aa00a032e1-744x1039.png") }
    ]
  },
  {
    slug: "legion",
    title: "Légion",
    category: "mots-cles",
    summary: "Bonus si vous avez joué une autre carte ce tour-ci.",
    details: [
      "« [Légion] — [Texte] » : la carte gagne le texte si vous avez joué une **autre carte** pendant ce tour.",
      "La condition s'évalue au moment où la carte Légion est jouée/résolue."
    ],
    cases: [
      {
        q: "Une rune canalisée compte-t-elle comme « carte jouée » pour Légion ?",
        a: "Non : canaliser n'est pas jouer. Il faut avoir joué une carte du deck principal (ou le champion élu) ce tour."
      }
    ],
    sections: ["812"],
    examples: [
      { id: "ogn-012-298", name: "Noxus Hopeful", img: img("c3bb6f4cb58feeb50e396d12ec9865c5434025af-744x1039.png") }
    ]
  },
  {
    slug: "niveau",
    title: "Niveau (et XP)",
    category: "mots-cles",
    summary: "« Tant que vous avez N XP ou plus, cette carte a [Texte]. »",
    details: [
      "L'**XP** est un compteur de joueur qui ne se dépense pas tout seul : il se gagne via des effets (dont **Chasse**) et certains coûts le consomment.",
      "**Niveau N** : tant que votre total d'XP atteint N, la carte gagne le texte associé — sur le plateau comme ailleurs si précisé."
    ],
    cases: [
      {
        q: "Je passe sous le seuil d'XP (un coût m'en fait dépenser). Le bonus Niveau disparaît ?",
        a: "Oui : Niveau est une compétence continue conditionnée à votre total d'XP actuel."
      }
    ],
    sections: ["824", "728"],
    examples: [
      { id: "unl-016-219", name: "Scorchclaw", img: img("f69940824f8ce62a479df28988dcbdf6ea6d3960-744x1039.png") }
    ]
  },
  {
    slug: "chasse",
    title: "Chasse",
    category: "mots-cles",
    summary: "Quand l'unité conquiert ou occupe, son contrôleur gagne X XP.",
    details: [
      "« Lorsque je conquiers ou que j'occupe, le joueur qui me contrôle gagne X XP. »",
      "Se combine avec Niveau : les unités Chasse alimentent vos seuils d'XP."
    ],
    cases: [
      {
        q: "Deux unités Chasse sur le même champ quand je marque : double XP ?",
        a: "Chaque compétence Chasse se déclenche : oui, chacune donne son XP."
      }
    ],
    sections: ["823", "728"],
    examples: [
      { id: "unl-016-219", name: "Scorchclaw", img: img("f69940824f8ce62a479df28988dcbdf6ea6d3960-744x1039.png") }
    ]
  },
  {
    slug: "amplification",
    title: "Amplification / Amplifié",
    category: "mots-cles",
    summary: "Payez une fois pour amplifier le permanent ; tant qu'il l'est, il gagne le texte Amplifié.",
    details: [
      "**Amplification** : « [Coût] : amplifiez ceci » — utilisable seulement si le permanent n'est pas déjà amplifié.",
      "**Amplifié** : « tant que je suis amplifié, cette carte gagne [Texte] » — un état durable, pas un effet de tour."
    ],
    cases: [
      {
        q: "L'état amplifié disparaît-il en fin de tour ?",
        a: "Non : c'est un état durable du permanent, il persiste tant que le permanent reste en jeu."
      }
    ],
    sections: ["827", "828", "441"],
    examples: [
      {
        id: "ven-001-166",
        name: "Baccai Sandspinner",
        img: img("d8abab7f0df7c8ec9fff8c8dfa71c732e1ce2e6a-744x1039.png")
      }
    ]
  },
  {
    slug: "protection",
    title: "Protection",
    category: "mots-cles",
    summary: "Les sorts et compétences adverses qui ciblent cette carte coûtent X essence de plus.",
    details: [
      "Chaque fois qu'un sort ou une compétence contrôlé par un adversaire choisit cette carte, il coûte un supplément en essence runique égal à la valeur de Protection.",
      "Vos propres sorts ne sont pas taxés. Les effets qui n'utilisent pas de ciblage ne sont pas affectés."
    ],
    cases: [
      {
        q: "Un sort adverse qui touche « toutes les unités » paie-t-il la Protection ?",
        a: "Non : sans ciblage, pas de surcoût. Protection ne taxe que les sorts et compétences qui choisissent la carte."
      }
    ],
    sections: ["809"],
    examples: [
      { id: "ogn-013-298", name: "Pouty Poro", img: img("d541bf3bcb5aa3ad0d48d87f5753569b72ac426f-744x1039.png") }
    ]
  },
  {
    slug: "repetition",
    title: "Répétition",
    category: "mots-cles",
    summary: "Payez le coût supplémentaire : les instructions s'exécutent une seconde fois.",
    details: [
      "« Quand vous jouez ceci, vous pouvez payer un coût supplémentaire de [Coût]. Si vous le faites, exécutez les instructions une fois de plus lors de la résolution. »",
      "Le choix et le paiement se font au moment de jouer la carte."
    ],
    cases: [
      {
        q: "Puis-je choisir deux cibles différentes pour les deux exécutions ?",
        a: "Les instructions sont exécutées une fois de plus lors de la résolution : les nouveaux choix qui en découlent sont refaits si l'effet le permet (voir la carte et la règle 750 sur les nouveaux choix)."
      }
    ],
    sections: ["820", "750"],
    examples: [
      { id: "sfd-003-221", name: "Blood Rush", img: img("931b77b9ab56c3abc85686be4d2452c450f9b3e0-744x1039.png") }
    ]
  },
  {
    slug: "flux",
    title: "Flux",
    category: "mots-cles",
    summary: "Jouable depuis votre défausse pour son coût de flux, puis banni.",
    details: [
      "« Vous pouvez jouer ceci de votre défausse pour son coût de flux. Puis bannissez-le. »",
      "La carte part en zone de bannissement après usage : pas de boucle infinie."
    ],
    cases: [
      {
        q: "Puis-je jouer la carte depuis la main ET depuis la défausse ?",
        a: "Oui : depuis la main au coût normal (défausse ensuite), puis depuis la défausse au coût de flux (bannie ensuite)."
      }
    ],
    sections: ["829"],
    examples: [
      { id: "ven-003-166", name: "Brittle Steel", img: img("2264ab788558ec69b1b6ed3e03ce69a3f63bdbb7-744x1039.png") }
    ]
  },
  {
    slug: "equiper-degainer",
    title: "Équiper et Dégainer",
    category: "mots-cles",
    summary: "Équiper : compétence activée d'attache. Dégainer : équipe immédiatement, en Réaction.",
    details: [
      "**Équiper** : « [Coût] : équipez cet équipement à une unité que vous contrôlez » — phase principale, état ouvert.",
      "**Dégainer** : quand vous jouez l'objet, équipez-le immédiatement à une unité que vous contrôlez ; le tout avec les permissions d'une Réaction."
    ],
    cases: [
      {
        q: "Puis-je ré-équiper un objet d'une unité à une autre ?",
        a: "Oui, en payant à nouveau son coût d'Équiper : l'objet se détache et s'attache à la nouvelle unité."
      }
    ],
    sections: ["818", "819", "434"],
    examples: [
      { id: "sfd-002-221", name: "Armed Assailant", img: img("1debdef1d45f7b2a452951db39674aeb01a8dc2b-744x1039.png") }
    ]
  },
  {
    slug: "expert-en-armes",
    title: "Expert en armes",
    category: "mots-cles",
    summary: "En jouant l'unité, équipez-lui un Objet à coût réduit.",
    details: [
      "« Lorsque vous me jouez, choisissez une carte Objet que vous contrôlez ; payez son coût d'Équiper réduit de [X] pour l'équiper à cette unité. »",
      "Réactive au passage les parties inactives de la description de l'Objet."
    ],
    cases: [
      {
        q: "L'Objet est déjà porté par une autre unité : Expert en armes peut-il le voler ?",
        a: "Il choisit une carte Objet que vous contrôlez : oui, il peut la ré-équiper sur la nouvelle unité en payant le coût réduit."
      }
    ],
    sections: ["821"],
    examples: [
      { id: "sfd-002-221", name: "Armed Assailant", img: img("1debdef1d45f7b2a452951db39674aeb01a8dc2b-744x1039.png") }
    ]
  },
  {
    slug: "unique",
    title: "Unique",
    category: "mots-cles",
    summary: "Contrainte de construction : un seul exemplaire dans le deck.",
    details: [
      "Unique n'est pas un effet en jeu : c'est une restriction de construction de deck — un seul exemplaire de cette carte, au lieu des 3 habituels."
    ],
    cases: [
      {
        q: "Puis-je avoir deux Uniques différents ?",
        a: "Oui : la limite s'applique par nom de carte, pas au mot-clé."
      }
    ],
    sections: ["825"],
    examples: [
      { id: "sfd-190-221", name: "Forgefire Cape", img: img("9bc49433a6ec5a8f4f1b44351094523d51b6bc11-744x1039.png") }
    ]
  }
]

export const topicBySlug = (slug) => TOPICS.find((t) => t.slug === slug)
