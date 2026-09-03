/* Aide avancée : un sujet = une page complète.
   `sections` référence les sections des règles officielles (rules-fr.json),
   affichées en intégralité au bas de chaque page. `examples` montre de vraies
   cartes (CDN officiel Riot). `demo` décrit une mini-scène animée. */

const CDN = "https://cmsassets.rgpub.io/sanity/images/dsfx7636/game_data_live"
const img = (hash) => `${CDN}/${hash}?auto=format&fit=max&w=560&accountingTag=RB`

export const CATEGORIES = [
  { key: "modes", label: "Modes de jeu" },
  { key: "tour", label: "Tour & timing" },
  { key: "combat", label: "Combat" },
  { key: "points", label: "Champs de bataille & points" },
  { key: "cartes", label: "Cartes & ressources" },
  { key: "mots-cles", label: "Mots-clés" }
]

export const TOPICS = [
  /* ================= Modes de jeu ================= */
  {
    slug: "mode-duel",
    title: "Duel (1c1)",
    category: "modes",
    summary: "Le format de référence : deux joueurs, une manche sèche, premier à 8 points.",
    details: [
      "Le **duel** oppose deux joueurs, chacun pour soi, en une seule manche. Deux champs de bataille en jeu, victoire à **8 points**. C'est le format des parties rapides et de la plupart des tournois.",
      "**Ce que chacun apporte.** Un deck complet : une **légende de champion** (elle fixe l'identité de domaine — toutes vos cartes doivent y correspondre), un **deck principal d'au moins 40 cartes** dont votre **champion élu** (même tag de champion que la légende, maximum 3 exemplaires d'un même nom, maximum 3 cartes signature), un **deck de runes de 12 runes**, et **3 champs de bataille** de noms différents.",
      "**Mise en place, pas à pas.** 1 — Chaque joueur pose sa légende dans sa zone de légende et son champion élu dans sa zone de champion. 2 — Chaque joueur tire **au hasard un** de ses trois champs de bataille ; les deux autres sont écartés pour la partie. Les deux champs retenus sont placés côte à côte au centre. 3 — Chacun mélange son deck principal et son deck de runes, séparément. 4 — Le **premier joueur est tiré au sort** (pile ou face, dé… n'importe quelle méthode acceptée). 5 — Tout le monde pioche **4 cartes**.",
      "**Le mulligan.** Dans l'ordre des tours, chaque joueur peut mettre de côté **jusqu'à 2 cartes** de sa main, piocher autant de nouvelles cartes, puis **recycler** les cartes mises de côté (elles retournent sous le deck, mélangées). Une seule fois par joueur.",
      "**Ajustement du premier tour.** Le joueur qui joue en **second** canalise **une rune de plus** à sa première canalisation (3 au lieu de 2) — la compensation officielle de l'avantage de commencer.",
      "**Le tour de jeu.** Chaque tour suit le même squelette. **Éveil** : vous préparez tout ce que vous contrôlez. **Phase de départ** : les effets de début de tour se déclenchent, puis l'**étape des scores** — +1 point par champ de bataille que vous contrôlez encore (l'occupation). **Canalisation** : 2 runes passent de votre deck de runes à votre zone de runes. **Pioche** : 1 carte. **Phase principale** : jouez des cartes, déplacez vos unités, contestez les champs de bataille — les combats et confrontations s'y insèrent librement. **Fin de tour** : toutes les unités sont soignées, les effets « ce tour » expirent, la main passe.",
      "**Marquer des points.** Deux façons, liées aux champs de bataille. **Conquérir** : prendre le contrôle d'un champ qui ne vous a pas encore rapporté ce tour (+1 point). **Occuper** : le contrôler encore à l'étape des scores de votre phase de départ (+1). Un même champ ne rapporte qu'**un point par tour et par joueur**.",
      "**La règle du dernier point.** À **7 points**, la conquête ne suffit plus : pour gagner le dernier point en conquérant, il faut avoir marqué **sur chaque champ de bataille pendant ce tour** (ici, les deux). Sinon, à la place du point, vous **piochez une carte**. L'occupation, elle, n'est pas restreinte : tenir un champ jusqu'à votre phase de départ donne le 8ᵉ point normalement.",
      "**Victoire.** Dès qu'un nettoyage a lieu (le jeu vérifie l'état après chaque action), un joueur ayant **au moins 8 points et strictement plus que l'adversaire** gagne. Une égalité à 8 ne donne donc pas la victoire : il faut creuser l'écart.",
      "**Deck vide : l'exténuation.** Si vous devez piocher et que le deck est vide, vous **mélangez votre défausse pour reformer votre deck**, votre **adversaire marque 1 point**, puis vous terminez la pioche. Défausse vide aussi ? L'exténuation se répète à chaque tentative — l'adversaire finit par gagner. Faire durer la partie a un prix."
    ],
    cases: [
      {
        q: "Nous sommes tous les deux à 8 points. Qui gagne ?",
        a: "Personne pour l'instant : il faut atteindre 8 et devancer strictement l'adversaire. Le premier qui prend un point d'avance l'emporte."
      },
      {
        q: "Je suis à 7 points et je conquiers un champ de bataille. Pourquoi n'ai-je pas gagné ?",
        a: "Le dernier point par conquête exige d'avoir marqué sur chaque champ de bataille ce tour-là. Si ce n'est pas le cas, vous piochez une carte à la place du point. Passez par l'occupation (tenir le champ jusqu'à votre prochaine phase de départ) ou conquérez les deux champs dans le même tour."
      },
      {
        q: "Mon deck est vide et je dois piocher. Que se passe-t-il exactement ?",
        a: "Exténuation : vous mélangez votre défausse pour reformer votre deck, votre adversaire marque 1 point, puis vous piochez. Si la défausse est vide aussi, l'exténuation se répète jusqu'à ce que l'adversaire gagne."
      },
      {
        q: "Combien de cartes puis-je changer au mulligan ?",
        a: "Jusqu'à 2 : mettez-les de côté, piochez autant, puis recyclez-les. Une seule fois, dans l'ordre des tours."
      },
      {
        q: "Puis-je reprendre un point à l'adversaire ?",
        a: "Non : les points gagnés ne se perdent pas (sauf effet explicite). On ne « vole » pas de points, on court chacun vers 8."
      },
      {
        q: "Qui choisit le champ de bataille joué ?",
        a: "Personne : chacun tire au hasard un de ses trois champs. Le choix délibéré, c'est le mode Match."
      }
    ],
    sections: ["481", "485"]
  },
  {
    slug: "mode-match",
    title: "Match (1c1, deux manches gagnantes)",
    category: "modes",
    summary: "Le duel au meilleur des manches : champs de bataille choisis, premier à deux manches gagnées.",
    details: [
      "Le **match** est un duel joué en **deux manches gagnantes** (trois en grand tournoi). Chaque manche se joue exactement comme un duel — mêmes decks, mêmes tours, même course à 8 points — c'est la structure de la rencontre qui change, et une liberté en plus : le **choix** du champ de bataille.",
      "**Ce que chacun apporte.** Comme en duel : légende de champion, deck principal d'au moins 40 cartes avec champion élu, deck de runes de 12, et 3 champs de bataille de noms différents.",
      "**Mise en place d'une manche.** Identique au duel, à une différence près : chaque joueur **choisit** le champ de bataille qu'il présente (au lieu de le tirer au hasard). Les deux champs présentés sont posés au centre, decks mélangés, premier joueur tiré au sort, 4 cartes piochées, mulligan (jusqu'à 2 cartes).",
      "**Réutiliser un champ de bataille.** Tant qu'aucune manche n'a été gagnée, un champ déjà présenté peut resservir. En **trois manches gagnantes**, les manches 4 et 5 permettent de représenter un champ retiré — à condition d'avoir déjà présenté chacun de ses trois champs au moins une fois, et jamais plus de deux fois le même dans le match.",
      "**Ajustement du premier tour** de chaque manche : le joueur qui joue en second canalise une rune de plus à sa première canalisation.",
      "**Le tour de jeu** est celui du duel : éveil → phase de départ (effets, puis étape des scores : +1 par champ contrôlé) → canalisation (2 runes) → pioche (1 carte) → phase principale (cartes, déplacements, combats et confrontations) → fin de tour (tout le monde est soigné, la main passe).",
      "**Marquer et gagner une manche.** Conquête (+1 en prenant un champ qui n'a pas encore rapporté ce tour) et occupation (+1 par champ tenu à votre étape des scores) ; un point maximum par champ et par tour. **Dernier point** : à 7, la conquête n'offre le point que si vous avez marqué sur chaque champ ce tour — sinon vous piochez une carte. La manche est gagnée à **8 points en étant strictement devant**.",
      "**Entre deux manches.** Tout l'état de jeu est remis à zéro : decks remélangés, nouvelles mains (et nouveau mulligan), nouveaux champs présentés, nouveau tirage du premier joueur. Seul le **compte des manches** est conservé. Premier à **2 manches** : match gagné.",
      "**Deck vide** : exténuation, comme en duel — défausse mélangée dans le deck, 1 point à l'adversaire, puis la pioche s'achève."
    ],
    cases: [
      {
        q: "Entre deux manches, est-ce que je garde mes points, mon XP ou mes runes ?",
        a: "Non : tout est réinitialisé, y compris les points, l'XP, les runes et les dégâts. Seules les manches gagnées se conservent."
      },
      {
        q: "Puis-je présenter le même champ de bataille à chaque manche ?",
        a: "Tant que vous n'avez pas encore gagné de manche avec lui, oui. En trois manches gagnantes, il faut avoir présenté chacun de ses trois champs avant d'en réutiliser un, et jamais plus de deux fois le même."
      },
      {
        q: "Pourquoi choisir son champ de bataille change-t-il la stratégie ?",
        a: "Le champ présenté devient un choix d'adaptation : après une manche perdue, présenter un autre champ (ou anticiper celui de l'adversaire) fait partie du jeu — c'est le côté « side » du format."
      },
      {
        q: "Qui commence la deuxième manche ?",
        a: "Le premier joueur est retiré au sort à chaque manche, comme au début d'un duel."
      },
      {
        q: "Puis-je modifier mon deck entre deux manches ?",
        a: "Non : le deck reste identique pendant tout le match. Seul le champ de bataille présenté change."
      }
    ],
    sections: ["481", "486"]
  },
  {
    slug: "mode-escarmouche",
    title: "Escarmouche (3 joueurs)",
    category: "modes",
    summary: "Chacun pour soi à trois : trois champs de bataille, alliances de circonstance, premier à 8 points.",
    details: [
      "L'**escarmouche** oppose **trois joueurs, chacun pour soi** : deux adversaires chacun, pas d'équipe, une seule manche, victoire à **8 points**. Trois champs de bataille en jeu — un par joueur.",
      "**Ce que chacun apporte.** Un deck complet : légende de champion (identité de domaine), deck principal d'au moins 40 cartes avec champion élu, deck de runes de 12, et 3 champs de bataille de noms différents.",
      "**Mise en place, pas à pas.** 1 — Légendes et champions élus posés dans leurs zones. 2 — Chaque joueur tire **au hasard un** de ses trois champs de bataille (les deux autres sont écartés) : **trois champs** forment le centre de la table. 3 — Decks mélangés séparément. 4 — **Premier joueur tiré au sort** ; l'ordre des tours suit ensuite la table dans le **sens horaire** à partir de lui, en boucle jusqu'à la fin. 5 — Tout le monde pioche 4 cartes, puis mulligan dans l'ordre des tours (jusqu'à 2 cartes mises de côté, repiochées, recyclées).",
      "**Ajustements du premier tour.** Le **premier** joueur **ne pioche pas** à sa première phase de pioche. Le **dernier** joueur de l'ordre canalise **une rune de plus** à sa première canalisation. Entre les deux, rien ne change.",
      "**Le tour de jeu.** Le squelette habituel : éveil → phase de départ (effets, puis étape des scores : +1 par champ que vous contrôlez) → canalisation (2 runes) → pioche (1 carte) → phase principale → fin de tour. Pendant la phase principale, vous pouvez contester **n'importe quel champ de bataille**, y compris celui d'un joueur qui ne vous a rien fait — la table est ouverte.",
      "**Marquer des points.** Conquérir un champ qui ne vous a pas rapporté ce tour : +1. L'occuper encore à votre étape des scores : +1. Un point maximum par champ et par tour. À trois, garder un champ un tour complet est difficile : les deux autres ont chacun leur tour pour vous déloger.",
      "**La règle du dernier point.** À **7 points**, le dernier point par **conquête** exige d'avoir marqué **sur les trois champs pendant le même tour** — sinon, vous piochez une carte à la place. L'**occupation** n'est pas restreinte : tenir un champ jusqu'à votre phase de départ donne le 8ᵉ point normalement. Conséquence pratique : le joueur à 7 points devient la cible commune, et c'est voulu.",
      "**Victoire.** Au moins 8 points **et strictement plus que chacun des deux autres**. Deux joueurs à 8 ? Personne ne gagne encore : la partie continue jusqu'à ce que quelqu'un se détache.",
      "**Deck vide : l'exténuation.** Vous mélangez votre défausse pour reformer le deck, puis **vous choisissez lequel de vos adversaires marque 1 point**, et la pioche s'achève. Ce choix est une arme politique : donner le point au joueur le moins menaçant fait partie du jeu — mais jamais à un joueur que cela ferait gagner sans y penser.",
      "**La dimension diplomatique.** Rien dans les règles n'interdit de se concerter (« occupe-toi de lui, je te laisse tranquille ce tour »), mais rien ne rend ces promesses contraignantes. Les alliances de circonstance se font et se défont — seul le score compte."
    ],
    cases: [
      {
        q: "Je suis exténué : qui marque le point ?",
        a: "Vous choisissez lequel de vos deux adversaires reçoit le point — à chaque exténuation. Attention en fin de partie : ce point peut faire gagner."
      },
      {
        q: "Deux joueurs sont à 8. Le troisième peut-il encore gagner ?",
        a: "Oui : personne ne gagne tant qu'il n'est pas strictement devant tous les autres. La partie continue, et le troisième peut recoller puis passer devant."
      },
      {
        q: "Pourquoi le premier joueur ne pioche-t-il pas ?",
        a: "C'est la compensation officielle du multijoueur : commencer donne un temps d'avance, la pioche sautée le rééquilibre — et le dernier joueur canalise une rune de plus."
      },
      {
        q: "Puis-je attaquer le champ de bataille de n'importe qui ?",
        a: "Oui. Tous les champs en jeu sont contestables par tous, quel que soit celui qui les a fournis."
      },
      {
        q: "Dans quel ordre joue-t-on ?",
        a: "Sens horaire à partir du premier joueur tiré au sort, en boucle. C'est aussi l'ordre que suit le compteur de l'application."
      },
      {
        q: "Un adversaire conquiert « mon » champ de bataille. Est-ce pire pour moi ?",
        a: "Non : le champ que vous avez fourni n'a rien de spécial pour vous en jeu. Il rapporte des points à qui le contrôle, comme les autres."
      },
      {
        q: "Les accords entre joueurs sont-ils autorisés ?",
        a: "Discuter, promettre, menacer : oui. Mais rien n'est contraignant, et les informations privées (votre main) le restent sauf si vous choisissez de les révéler."
      }
    ],
    sections: ["481", "487"]
  },
  {
    slug: "mode-guerre",
    title: "Guerre (4 joueurs)",
    category: "modes",
    summary: "Chacun pour soi à quatre : trois champs pour quatre joueurs, le premier joueur sacrifie les siens.",
    details: [
      "La **guerre** oppose **quatre joueurs, chacun pour soi** : trois adversaires chacun, pas d'équipe, une seule manche, victoire à **8 points**. Particularité : il n'y a que **trois champs de bataille** pour quatre joueurs.",
      "**Ce que chacun apporte.** Un deck complet : légende de champion (identité de domaine), deck principal d'au moins 40 cartes avec champion élu, deck de runes de 12, et 3 champs de bataille de noms différents.",
      "**Mise en place, pas à pas.** 1 — Légendes et champions élus posés dans leurs zones. 2 — **Premier joueur tiré au sort** : il **retire ses champs de bataille**, qui ne serviront pas. 3 — Les trois autres joueurs tirent chacun **au hasard un** de leurs trois champs : ces trois champs forment le centre de la table. 4 — Decks mélangés séparément ; l'ordre des tours suit la table dans le **sens horaire** à partir du premier joueur. 5 — Tout le monde pioche 4 cartes, puis mulligan dans l'ordre des tours (jusqu'à 2 cartes).",
      "**Ajustements du premier tour.** Le **premier** joueur **ne pioche pas** à sa première phase de pioche (en plus d'avoir retiré ses champs). Le **dernier** joueur — le quatrième — canalise **une rune de plus** à sa première canalisation.",
      "**Le tour de jeu.** Squelette habituel : éveil → phase de départ (effets, puis étape des scores : +1 par champ que vous contrôlez) → canalisation (2 runes) → pioche (1 carte) → phase principale → fin de tour. Tous les champs sont contestables par tous, à tout moment de votre phase principale.",
      "**Marquer des points.** Conquête (+1 en prenant un champ qui n'a pas rapporté ce tour) et occupation (+1 par champ tenu à votre étape des scores) ; un point maximum par champ et par tour. À quatre pour trois champs, il y a toujours au moins un joueur sans point d'ancrage : les rapports de force se déplacent tour après tour.",
      "**La règle du dernier point.** À **7 points**, le dernier point par **conquête** exige d'avoir marqué **sur les trois champs pendant le même tour** — sinon, une carte piochée à la place. L'**occupation**, elle, donne le 8ᵉ point normalement. Un joueur à 7 est donc sous la surveillance des trois autres : le déloger avant sa phase de départ devient l'affaire commune.",
      "**Victoire.** Au moins 8 points **et strictement plus que chacun des trois autres**, vérifié à chaque nettoyage. Les égalités ne donnent rien : on continue.",
      "**Deck vide : l'exténuation.** Défausse mélangée dans le deck, puis **vous choisissez lequel de vos trois adversaires marque 1 point**, et la pioche s'achève. Défausse vide aussi ? Exténuations en boucle — quelqu'un finira par gagner grâce à vous.",
      "**Rythme et table.** C'est le format le plus long et le plus politique : quatre decks, des confrontations plus fréquentes, des négociations permanentes. Le compteur de l'application affiche les quatre panneaux en carré et l'ordre des tours fait le tour de la table."
    ],
    cases: [
      {
        q: "Pourquoi le premier joueur retire-t-il ses champs de bataille ?",
        a: "Quatre joueurs, trois champs : le mode retire ceux du premier joueur, en contrepartie de l'avantage de commencer. Il joue la partie sur les champs des trois autres."
      },
      {
        q: "Le premier joueur est-il désavantagé ?",
        a: "Il perd ses champs et sa première pioche, mais il joue avant tout le monde : conquêtes précoces, tempo, premières confrontations. Le mode équilibre, il ne punit pas."
      },
      {
        q: "Je suis à 7 points : comment gagner ?",
        a: "Soit l'occupation (tenir un champ jusqu'à votre phase de départ), soit une conquête en ayant marqué sur les trois champs dans le même tour. Une conquête isolée ne donne qu'une carte piochée."
      },
      {
        q: "Je suis exténué : qui marque le point ?",
        a: "Vous choisissez lequel de vos trois adversaires reçoit le point. Ne le donnez jamais à un joueur à 7 points sans le vouloir : ce point-là gagne immédiatement la partie."
      },
      {
        q: "Dans quel ordre joue-t-on ?",
        a: "Sens horaire à partir du premier joueur tiré au sort, en boucle jusqu'à la fin — l'ordre que suit aussi le compteur de l'application."
      },
      {
        q: "Peut-on s'allier ?",
        a: "Se concerter, oui ; rien n'est contraignant. Les alliances durent le temps qu'elles servent — et le joueur en tête le sait."
      }
    ],
    sections: ["481", "488"]
  },
  {
    slug: "mode-chambre-magmatique",
    title: "Chambre magmatique (2c2)",
    category: "modes",
    summary: "Deux équipes de deux : score commun à 11, tours alternés, entraide encadrée par des règles précises.",
    details: [
      "La **chambre magmatique** oppose **deux équipes de deux joueurs**. Le score est **commun à l'équipe** — on gagne et on perd ensemble — et la victoire se joue à **11 points**. Tout le reste (main, decks, runes, XP) appartient à chaque joueur.",
      "**Ce que chacun apporte.** Un deck complet par joueur : légende de champion, deck principal d'au moins 40 cartes avec champion élu, deck de runes de 12, 3 champs de bataille. Deux contraintes d'équipe : les coéquipiers **ne peuvent pas utiliser la même légende de champion**, ni **les mêmes champs de bataille**.",
      "**Mise en place, pas à pas.** 1 — Légendes et champions élus posés dans leurs zones. 2 — **Premier joueur tiré au sort** : il **retire ses champs de bataille**. 3 — Les trois autres joueurs tirent chacun **au hasard un** de leurs trois champs : trois champs au centre. 4 — Decks mélangés séparément. 5 — Pioche de 4 cartes, puis mulligan dans l'ordre des tours (jusqu'à 2 cartes).",
      "**L'ordre des tours alterne entre les équipes**, toujours : le premier joueur, puis **un adversaire**, puis le **coéquipier du premier joueur**, puis le **coéquipier de cet adversaire** — et on recommence. Jamais deux tours de la même équipe d'affilée. (Coéquipiers face à face : l'ordre suit le sens horaire ; coéquipiers côte à côte : l'ordre traverse la table.)",
      "**Ajustements du premier tour.** Le premier joueur **ne pioche pas** à sa première pioche ; le **dernier** joueur canalise **une rune de plus** à sa première canalisation.",
      "**Le tour de jeu** garde le squelette habituel : éveil → phase de départ (effets, puis étape des scores : +1 pour l'équipe par champ que **vous** contrôlez) → canalisation (2 runes) → pioche (1 carte) → phase principale → fin de tour.",
      "**Jouer pendant le tour de son coéquipier.** C'est permis — sorts et compétences — mais uniquement **sur invitation** : le joueur du tour utilise sa priorité pour inviter son coéquipier à agir. Vos mains restent privées, mais rien n'interdit de se montrer ses cartes ou de tout se dire.",
      "**Ce que l'équipe ne partage pas.** Le **contrôle** : vous ne pouvez pas cacher de carte sur un champ contrôlé par votre coéquipier, ni faire faire de déplacement standard à ses unités. Chacun joue ses cartes, ses runes, son XP. Le mot **allié** sur les cartes désigne vos éléments **et** ceux de votre coéquipier.",
      "**Marquer des points (score commun).** Conquête : +1 pour l'équipe en prenant un champ qui n'a pas rapporté ce tour. Occupation : +1 par champ que vous contrôlez à votre étape des scores. Deux subtilités d'équipe : un champ contrôlé par votre **coéquipier** pendant **votre** phase de départ ne peut pas rapporter de point à votre équipe **ce tour-là** (ni par occupation ni en le « reconquérant ») — pas de points gratuits en se passant les champs.",
      "**La règle du dernier point, version 2c2.** À **10 points**, le dernier point par **conquête** exige de marquer **sur tous les champs de bataille pendant le même tour**, à l'exception de ceux occupés par votre coéquipier pendant l'étape des scores — sinon, une carte piochée à la place. L'occupation donne le 11ᵉ point normalement.",
      "**Victoire.** Au moins **11 points** pour l'équipe et strictement plus que l'équipe adverse, vérifié à chaque nettoyage. Si un joueur abandonne, **toute son équipe perd** ; si un joueur gagne, toute son équipe gagne.",
      "**Deck vide : l'exténuation.** Le joueur exténué mélange sa défausse dans son deck et **l'équipe adverse marque 1 point**, puis la pioche s'achève."
    ],
    cases: [
      {
        q: "Mon coéquipier et moi partageons-nous les runes, les cartes ou l'XP ?",
        a: "Non : seul le score est commun. Chacun garde sa main (privée, mais montrable), son deck, ses runes et son XP."
      },
      {
        q: "Puis-je jouer pendant le tour de mon coéquipier ?",
        a: "Oui, sorts et compétences, mais seulement s'il vous y invite avec sa priorité. Vous ne pouvez pas vous imposer dans son tour."
      },
      {
        q: "Mon coéquipier contrôle un champ. Puis-je marquer avec pendant mon tour ?",
        a: "Non : un champ contrôlé par votre coéquipier pendant votre phase de départ ne peut pas rapporter de point à votre équipe ce tour-là. Chacun marque avec les champs qu'il contrôle lui-même."
      },
      {
        q: "Puis-je déplacer les unités de mon coéquipier ou cacher une carte sur son champ ?",
        a: "Non : le contrôle n'est pas partagé. Pas de déplacement standard de ses unités, pas de carte cachée sur ses champs de bataille."
      },
      {
        q: "Qui joue après moi ?",
        a: "Toujours un adversaire : les tours alternent strictement entre les équipes (premier joueur, adversaire, coéquipier, coéquipier de l'adversaire, et on boucle)."
      },
      {
        q: "Nous sommes à 10 points : comment gagner le dernier ?",
        a: "Par l'occupation, normalement. Par la conquête, seulement en marquant sur tous les champs le même tour (hors champs occupés par votre coéquipier à l'étape des scores) — sinon le conquérant pioche une carte à la place."
      },
      {
        q: "Pourquoi 11 points et pas 8 ?",
        a: "Deux joueurs alimentent le même compte : à 8, la course serait trop courte. Le mode rallonge la distance."
      },
      {
        q: "Pouvons-nous jouer la même légende ou les mêmes champs de bataille ?",
        a: "Non : les coéquipiers doivent avoir des légendes de champion différentes et des champs de bataille différents."
      },
      {
        q: "Un mot de carte dit « allié » : qui cela couvre-t-il ?",
        a: "Vos éléments de jeu et ceux de votre coéquipier. « Adversaire » désigne les deux joueurs de l'autre équipe."
      }
    ],
    sections: ["481", "489"]
  },

  /* ================= Tour & timing ================= */
  {
    slug: "deroulement-du-tour",
    title: "Le déroulement du tour",
    category: "tour",
    summary: "Éveil, scores, canalisation, pioche, phase principale, fin de tour : l'ordre exact.",
    details: [
      "Chaque tour commence par quatre phases automatiques, toujours dans le même ordre. **Phase d'éveil** : vous préparez (redressez) tous les éléments de jeu que vous contrôlez — unités, équipements, runes. **Phase de départ** : les effets « au début de votre phase de départ » se déclenchent, puis vient l'**étape des scores** où vous marquez 1 point par champ de bataille que vous contrôlez (l'occupation).",
      "**Phase de canalisation** : 2 runes passent du dessus de votre deck de runes à votre zone de runes. Elles y restent de tour en tour tant qu'elles ne sont pas recyclées : votre total de ressources grandit de 2 chaque tour. **Phase de pioche** : vous piochez 1 carte (deck vide : voyez l'exténuation).",
      "La **phase principale** n'a aucune structure imposée : jouez des cartes, activez des compétences, déplacez des unités, dans l'ordre que vous voulez, tant que vous pouvez payer. C'est un état « ouvert » : seul le joueur du tour peut jouer des sorts sans mot-clé de timing.",
      "Des combats et des confrontations peuvent s'insérer dans la phase principale à chaque fois qu'un champ de bataille devient contesté — ils se résolvent entièrement avant que la phase principale ne reprenne.",
      "Quand vous n'avez plus rien à faire, vous annoncez la **fin de votre tour** : les effets de fin de tour se déclenchent, toutes les unités sont soignées, les effets « pendant ce tour » expirent simultanément, la réserve runique se vide, puis le joueur suivant devient le joueur du tour."
    ],
    cases: [
      {
        q: "Je contrôle un champ de bataille conquis au tour précédent. Quand marque-t-il ?",
        a: "À l'étape des scores de votre phase de départ : +1 point d'occupation, avant même la canalisation et la pioche."
      },
      {
        q: "Puis-je jouer une carte pendant la phase d'éveil ou la canalisation ?",
        a: "Non. Les cartes se jouent en phase principale — ou pendant les confrontations pour les sorts [Action] et [Réaction]."
      },
      {
        q: "Mes unités blessées gardent-elles leurs dégâts d'un tour à l'autre ?",
        a: "Non : toutes les unités sont soignées à la fin de chaque tour, et lors de chaque nettoyage de combat. Les dégâts ne s'accumulent jamais d'un tour sur l'autre."
      },
      {
        q: "L'ordre des phases peut-il changer ?",
        a: "Non, les phases sont rigides (règle 303). En revanche, à l'intérieur de la phase principale, vos actions sont libres."
      },
      {
        q: "Un effet se déclenche « au début de votre tour » et un autre « au début de votre phase de départ ». Lequel d'abord ?",
        a: "Les déclenchements simultanés sont ordonnés par le joueur du tour ; les effets liés à une phase précise attendent cette phase (l'éveil précède la phase de départ)."
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
      "La **chaîne** est la zone où vont les cartes et compétences en train d'être jouées. Rien ne se résout instantanément : tout passe par la chaîne, ce qui laisse une fenêtre de réponse.",
      "Les réponses s'**empilent au-dessus** : si vous jouez un sort et que l'adversaire répond avec une [Réaction], sa Réaction se résout en premier, puis votre sort — dernier entré, premier résolu.",
      "Pendant qu'un objet de la chaîne se résout, **rien d'autre ne peut se résoudre** : on exécute toutes ses instructions du haut vers le bas, puis seulement on regarde ce qui a été déclenché entre-temps.",
      "Les compétences déclenchées pendant une résolution attendent la fin de cette résolution, puis sont ajoutées à la chaîne (par le joueur qui les contrôle) et résolues à leur tour.",
      "Payer les coûts n'utilise pas la chaîne : épuiser ou recycler une rune pour produire de l'énergie est immédiat et ne peut pas être « contré »."
    ],
    cases: [
      {
        q: "L'adversaire joue un sort qui élimine mon unité. Puis-je réagir ?",
        a: "Oui, avec un sort ou une compétence [Réaction] : elle s'empile au-dessus et se résout avant. Un sort [Action] ne suffit pas — l'état est fermé pendant qu'un objet attend dans la chaîne."
      },
      {
        q: "Mon sort déclenche une compétence en se résolvant. Quand se résout-elle ?",
        a: "Après la résolution complète de votre sort : on termine toutes ses instructions, puis la compétence déclenchée entre dans la chaîne."
      },
      {
        q: "L'adversaire peut-il réagir au moment où j'épuise mes runes ?",
        a: "Non : le paiement des coûts ne passe pas par la chaîne. Il réagit à la carte jouée, pas à la production de ressources."
      },
      {
        q: "Deux joueurs veulent réagir au même sort. Qui empile en premier ?",
        a: "L'ordre des tours s'applique à partir du joueur du tour : chacun, dans l'ordre, peut ajouter sa réponse — le dernier objet empilé se résoudra en premier."
      }
    ],
    sections: ["327", "332"],
    demo: {
      title: "La chaîne : empiler puis dépiler",
      frames: [
        {
          caption: "Vous jouez un sort : il entre dans la chaîne — il ne se résout pas tout de suite.",
          items: [
            { k: "z", type: "zone", x: 50, y: 50, label: "Chaîne" },
            { k: "a", type: "card", x: 50, y: 62, label: "Votre sort" }
          ]
        },
        {
          caption: "L'adversaire répond avec une Réaction : elle s'empile AU-DESSUS.",
          items: [
            { k: "z", type: "zone", x: 50, y: 50, label: "Chaîne" },
            { k: "a", type: "card", x: 50, y: 62, label: "Votre sort" },
            { k: "b", type: "card", side: "foe", x: 50, y: 34, label: "Sa Réaction", glow: true }
          ]
        },
        {
          caption: "Dernier entré, premier résolu : la Réaction se résout d'abord…",
          items: [
            { k: "z", type: "zone", x: 50, y: 50, label: "Chaîne" },
            { k: "a", type: "card", x: 50, y: 62, label: "Votre sort" },
            { k: "b", type: "card", side: "foe", x: 84, y: 34, label: "Résolue", dead: true }
          ]
        },
        {
          caption: "…puis votre sort se résout (s'il est toujours valide).",
          items: [
            { k: "z", type: "zone", x: 50, y: 50, label: "Chaîne" },
            { k: "a", type: "card", x: 84, y: 62, label: "Résolu", glow: true }
          ]
        }
      ]
    }
  },
  {
    slug: "confrontation-et-focalisation",
    title: "Confrontation et focalisation",
    category: "tour",
    summary: "Une fenêtre où chacun joue à tour de rôle ; deux passes consécutives la terminent.",
    details: [
      "Une **confrontation** s'ouvre au nettoyage qui suit la contestation d'un champ de bataille. C'est la grande fenêtre d'interaction du jeu : chacun, à tour de rôle, peut jouer des sorts et compétences [Action] ou [Réaction].",
      "La **focalisation** désigne le joueur « à qui c'est de parler ». Le joueur qui a contesté le champ la reçoit en premier.",
      "Avec la focalisation, deux choix : **jouer** une carte ou une compétence (ce qui ouvre une chaîne, résolue normalement), ou **passer**. Après chaque chaîne résolue, la focalisation passe au joueur suivant.",
      "La confrontation se termine quand **tous les joueurs passent successivement** sans rien jouer. S'il y a des unités des deux camps : le combat continue vers l'étape des dégâts. Sinon : le joueur seul présent prend le contrôle.",
      "Les confrontations existent aussi **sans combat** : contester un champ vide ouvre une confrontation ; si personne n'intervient, vous prenez le contrôle à la fin — et marquez la conquête."
    ],
    cases: [
      {
        q: "J'ai contesté un champ vide. Que se passe-t-il ?",
        a: "Une confrontation sans combat s'ouvre. Si à sa fin vous êtes le seul à y avoir des unités, vous prenez le contrôle — conquête si ce champ ne vous a pas déjà rapporté de point ce tour."
      },
      {
        q: "L'adversaire déplace une unité sur le champ pendant la confrontation sans combat. Et alors ?",
        a: "Impossible par déplacement standard (interdit pendant les confrontations) — mais possible via un effet ou une unité [Embuscade]. La confrontation devient alors une confrontation de combat au prochain nettoyage."
      },
      {
        q: "Je passe, l'adversaire joue un sort. Puis-je encore agir ?",
        a: "Oui : passer n'est définitif que si tout le monde passe d'affilée. Dès qu'un joueur joue, le compte des passes repart de zéro."
      },
      {
        q: "Qui a la focalisation quand une compétence déclenchée s'ajoute à la chaîne ?",
        a: "La focalisation n'est pas transférée dans ce cas (règle 346.1) : elle reste au même joueur après la résolution."
      }
    ],
    sections: ["341", "311"],
    demo: {
      title: "La focalisation passe de joueur en joueur",
      frames: [
        {
          caption: "Le champ est contesté : confrontation. Vous avez la focalisation.",
          items: [
            { k: "you", type: "card", x: 22, y: 60, label: "Vous" },
            { k: "foe", type: "card", side: "foe", x: 78, y: 40, label: "Adversaire" },
            { k: "f", type: "label", x: 22, y: 24, label: "Focalisation", glow: true }
          ]
        },
        {
          caption: "Vous jouez un sort Action. La chaîne se résout, la focalisation passe.",
          items: [
            { k: "you", type: "card", x: 22, y: 60, label: "Vous", glow: true },
            { k: "foe", type: "card", side: "foe", x: 78, y: 40, label: "Adversaire" },
            { k: "f", type: "label", x: 78, y: 24, label: "Focalisation", glow: true }
          ]
        },
        {
          caption: "L'adversaire passe. La focalisation vous revient.",
          items: [
            { k: "you", type: "card", x: 22, y: 60, label: "Vous" },
            { k: "foe", type: "card", side: "foe", x: 78, y: 40, label: "Adversaire" },
            { k: "p1", type: "label", x: 78, y: 62, label: "Passe" },
            { k: "f", type: "label", x: 22, y: 24, label: "Focalisation", glow: true }
          ]
        },
        {
          caption: "Vous passez aussi : deux passes consécutives, la confrontation se termine.",
          items: [
            { k: "you", type: "card", x: 22, y: 60, label: "Vous" },
            { k: "foe", type: "card", side: "foe", x: 78, y: 40, label: "Adversaire" },
            { k: "p1", type: "label", x: 78, y: 62, label: "Passe" },
            { k: "p2", type: "label", x: 22, y: 80, label: "Passe" },
            { k: "end", type: "label", x: 50, y: 44, label: "Fin de la confrontation", glow: true }
          ]
        }
      ]
    }
  },
  {
    slug: "extenuation",
    title: "L'exténuation (deck vide)",
    category: "tour",
    summary: "Piocher deck vide : la défausse redevient un deck, l'adversaire gagne 1 point.",
    details: [
      "L'**exténuation** se produit quand vous devez déplacer des cartes de votre deck principal (piocher, le plus souvent) alors qu'il n'en contient plus assez.",
      "Séquence exacte (règle 431.2) : faites l'action autant que possible, **mélangez votre défausse dans votre deck principal**, choisissez **un adversaire qui gagne 1 point**, puis terminez l'action qui a causé l'exténuation.",
      "C'est **une seule exténuation** par deck vidé — pas une par carte manquante. Piocher 3 avec 1 carte restante : une carte piochée, une exténuation, puis les 2 dernières pioches.",
      "**Regarder ou révéler** des cartes ne cause jamais d'exténuation : on regarde ce qu'on peut, les instructions irréalisables sont ignorées (règle 431.1.c).",
      "Deck ET défausse vides : chaque tentative répète l'exténuation, un point offert à chaque fois — la partie peut se terminer ainsi."
    ],
    cases: [
      {
        q: "Un effet me fait piocher 3 cartes et mon deck n'en a qu'une. Combien d'exténuations ?",
        a: "Une seule : vous piochez la carte restante, exténuation (mélange + 1 point offert), puis vous piochez les 2 manquantes — sauf si le nouveau deck se vide encore."
      },
      {
        q: "Je choisis quel adversaire gagne le point ?",
        a: "Oui : « choisir un adversaire qui gagnera 1 point » — en duel, pas de choix ; à 3-4 joueurs, le choix est libre."
      },
      {
        q: "Un effet me demande de révéler 5 cartes, il m'en reste 2. Exténuation ?",
        a: "Non : regarder ou révéler ne déclenche pas l'exténuation. Vous révélez 2 cartes, le reste de l'instruction s'adapte ou est ignoré."
      },
      {
        q: "L'adversaire peut-il refuser le point ?",
        a: "Non — et les points d'exténuation en chaîne ne peuvent être ni remplacés ni empêchés (règle 431.3.b)."
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
      "Le **nettoyage** est la routine d'entretien du jeu : il s'exécute après chaque action de jeu et chaque résolution, avant que quiconque reprenne la main.",
      "Il vérifie notamment : les unités dont les dégâts marqués atteignent la puissance sont **éliminées** ; les champs de bataille sans unités perdent leur contrôleur ; les confrontations dues aux contestations sont préparées ; la **victoire** est vérifiée.",
      "Toutes ces vérifications sont **simultanées** : deux unités qui ont chacune des dégâts mortels meurent ensemble, pas l'une après l'autre.",
      "Le **nettoyage de combat** (à la résolution d'un combat) insère deux étapes en plus : soigner toutes les unités, et rappeler les attaquants à leur base si des défenseurs restent.",
      "Le **nettoyage de fin de tour** ajoute : soigner toutes les unités, faire expirer les effets « pendant ce tour », vider la réserve runique."
    ],
    cases: [
      {
        q: "Mon unité et celle de l'adversaire atteignent des dégâts mortels en même temps. Qui meurt ?",
        a: "Les deux, simultanément : le nettoyage élimine ensemble toutes les unités dont les dégâts égalent ou dépassent la puissance."
      },
      {
        q: "Un joueur atteint 8 points pendant le tour adverse. Quand gagne-t-il ?",
        a: "Au nettoyage suivant : c'est lui qui vérifie la victoire, peu importe le joueur du tour — à condition d'avoir strictement plus de points que tout adversaire."
      },
      {
        q: "Une unité soignée par le nettoyage de combat peut-elle mourir du même combat ?",
        a: "Non : les dégâts de combat sont infligés avant, les éliminations constatées, puis les survivants sont soignés. Une unité soignée a survécu."
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
      "Un combat se déclenche quand des unités de **deux joueurs adverses** occupent le même champ de bataille. Il se déroule en trois étapes rigides.",
      "**Étape 1 — la confrontation de combat** : l'attaquant est le joueur qui a contesté le champ, le défenseur celui qui y était. L'attaquant reçoit la focalisation ; chacun joue ses [Action] et [Réaction] jusqu'à deux passes consécutives.",
      "**Étape 2 — les dégâts** : chaque camp additionne la **puissance** de ses unités présentes ; chacun attribue ce total aux unités adverses (voir la page Attribution), puis tout est infligé **simultanément**.",
      "**Étape 3 — la résolution** : nettoyage de combat (éliminations, soins, rappel des attaquants si des défenseurs restent), détermination du vainqueur, prise de contrôle par le camp resté seul — et conquête si ce champ n'a pas déjà rapporté de point ce tour.",
      "Les désignations « attaquant » et « défenseur » comptent pour les mots-clés : [Assaut] ne fonctionne qu'en attaque, [Bouclier] et [Tank] qu'avec la désignation correspondante."
    ],
    cases: [
      {
        q: "Qui est l'attaquant si une confrontation était déjà en cours quand le combat démarre ?",
        a: "L'attaquant est toujours le joueur dont les unités ont appliqué le statut contesté ; celui qui avait la focalisation la conserve."
      },
      {
        q: "Une unité arrive sur le champ en plein combat (Embuscade, effet). Attaquante ou défenseuse ?",
        a: "Elle reçoit la désignation de son camp au nettoyage qui suit son arrivée — et participera aux dégâts si elle est là à l'étape 2."
      },
      {
        q: "Puis-je fuir le combat avec un déplacement standard ?",
        a: "Non : le déplacement standard est interdit pendant les confrontations et combats. Seul un effet de jeu peut retirer une unité du combat."
      },
      {
        q: "Deux combats se préparent sur les deux champs. Lequel d'abord ?",
        a: "Le joueur du tour choisit l'ordre de résolution (règle 461.1). Chaque combat se résout entièrement avant le suivant."
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
      "À l'étape des dégâts, chaque joueur attribue le **total de puissance** de son camp aux unités adverses — c'est le joueur qui inflige qui choisit la répartition, dans des limites strictes.",
      "Règle n° 1 : une unité doit recevoir des **dégâts mortels** avant qu'une autre puisse en recevoir. Mortel = un total marqué (dégâts déjà présents inclus) au moins égal à sa puissance actuelle.",
      "Règle n° 2 : on n'attribue **jamais plus que le minimum mortel** à une unité — sauf s'il ne reste plus aucune autre cible, auquel cas le surplus lui est attribué.",
      "[Tank] impose de recevoir les dégâts mortels **en premier** ; [Arrière-ligne] **en dernier**. À priorité égale (deux Tanks), l'ordre est au choix du joueur qui attribue. Si une même unité cumule des exigences exclusives, le joueur qui attribue choisit laquelle appliquer.",
      "L'attribution n'est pas l'infliction : on répartit tout d'abord, puis **tout est infligé simultanément** — aucune unité ne meurt « avant » les autres pendant cette étape."
    ],
    cases: [
      {
        q: "L'adversaire a un Tank de 5 et je n'ai que 3 de puissance. Puis-je viser l'autre unité ?",
        a: "Non : tant que le Tank n'a pas reçu de dégâts mortels, personne d'autre ne peut en recevoir. Vos 3 dégâts partent sur le Tank, en pure perte (il sera soigné au nettoyage de combat)."
      },
      {
        q: "Deux unités adverses ont Tank. Laquelle en premier ?",
        a: "Au choix du joueur qui attribue : à priorité égale, l'ordre est libre."
      },
      {
        q: "Une unité déjà blessée de 2 (puissance 4) : combien pour la finir ?",
        a: "2 suffisent — les dégâts mortels se calculent sur le total marqué, pas sur les seuls dégâts de combat."
      },
      {
        q: "Il me reste 2 dégâts après avoir tué toutes les unités sauf une (puissance 6). Perdus ?",
        a: "Non : quand il ne reste plus qu'elle, le surplus lui est attribué — 2 dégâts marqués, insuffisants pour la tuer, soignés au nettoyage."
      },
      {
        q: "Une unité que rien ne peut blesser (immunité) bloque-t-elle mon attribution ?",
        a: "Non : une unité qui ne peut pas subir de dégâts n'a pas de « seuil mortel » et est exclue de l'attribution obligatoire (règle 465.2.c.10)."
      }
    ],
    sections: ["465", "417"],
    demo: {
      title: "Tank d'abord, Arrière-ligne en dernier",
      frames: [
        {
          caption: "Vous infligez 7 dégâts. En face : un Tank (4), une unité (3), une Arrière-ligne (2).",
          items: [
            { k: "total", type: "chip", x: 12, y: 30, n: "7 dégâts", ok: true },
            { k: "t", type: "unit", side: "foe", x: 38, y: 40, n: 4 },
            { k: "lt", type: "label", x: 38, y: 74, label: "Tank" },
            { k: "u", type: "unit", side: "foe", x: 62, y: 40, n: 3 },
            { k: "b", type: "unit", side: "foe", x: 86, y: 40, n: 2 },
            { k: "lb", type: "label", x: 86, y: 74, label: "Arrière-ligne" }
          ]
        },
        {
          caption: "Le Tank d'abord : 4 dégâts, le minimum mortel — pas un de plus.",
          items: [
            { k: "total", type: "chip", x: 12, y: 30, n: "3 restants", ok: true },
            { k: "t", type: "unit", side: "foe", x: 38, y: 40, n: 4, dead: true },
            { k: "d1", type: "chip", x: 38, y: 18, n: "−4" },
            { k: "u", type: "unit", side: "foe", x: 62, y: 40, n: 3 },
            { k: "b", type: "unit", side: "foe", x: 86, y: 40, n: 2 },
            { k: "lb", type: "label", x: 86, y: 74, label: "Arrière-ligne" }
          ]
        },
        {
          caption: "Puis l'unité normale : 3 dégâts, mortels. L'Arrière-ligne attend son tour.",
          items: [
            { k: "total", type: "chip", x: 12, y: 30, n: "0 restant", ok: true },
            { k: "u", type: "unit", side: "foe", x: 62, y: 40, n: 3, dead: true },
            { k: "d2", type: "chip", x: 62, y: 18, n: "−3" },
            { k: "b", type: "unit", side: "foe", x: 86, y: 40, n: 2 },
            { k: "lb", type: "label", x: 86, y: 74, label: "Arrière-ligne" }
          ]
        },
        {
          caption: "Plus de dégâts à répartir : l'Arrière-ligne survit. Tout est ensuite infligé simultanément.",
          items: [
            { k: "b", type: "unit", side: "foe", x: 86, y: 40, n: 2 },
            { k: "lb", type: "label", x: 86, y: 74, label: "Arrière-ligne" },
            { k: "ok", type: "label", x: 40, y: 40, label: "Survivante", glow: true }
          ]
        }
      ]
    }
  },
  {
    slug: "rappel-des-attaquants",
    title: "Le rappel des attaquants",
    category: "combat",
    summary: "Si les deux camps survivent, les attaquants rentrent à la base : défendre a l'avantage.",
    details: [
      "Au **nettoyage de combat**, après l'infliction des dégâts et les éliminations, une étape spéciale s'exécute : si des **défenseurs** sont encore présents, toutes les unités **attaquantes** restantes sont rappelées à la base de leur propriétaire.",
      "Le combat se termine alors sur « **aucun résultat** » : personne ne conquiert, le défenseur garde le contrôle du champ.",
      "Conséquence stratégique : attaquer sans pouvoir éliminer toute la défense ne rapporte rien — les unités rappelées reviennent épuisées à la base et devront re-traverser au tour suivant.",
      "Le rappel n'est pas une élimination ni un déplacement standard : il ne déclenche pas [Agonie], ne coûte rien et ignore les restrictions de déplacement."
    ],
    cases: [
      {
        q: "J'attaque avec 3 de puissance contre un défenseur de 4 : que se passe-t-il si personne ne meurt ?",
        a: "Vos unités survivantes sont rappelées à votre base, le défenseur garde son champ et sera soigné. L'attaque n'a rien rapporté."
      },
      {
        q: "Tous les défenseurs meurent, mais moi aussi je perds des unités. Qui gagne ?",
        a: "S'il ne reste que vos unités, vous prenez le contrôle (conquête). S'il ne reste personne, le champ devient non contrôlé — sans conquête pour personne."
      },
      {
        q: "Mon unité rappelée avait un équipement pris sur le champ. Il suit ?",
        a: "Oui : un équipement porté suit son unité, où qu'elle aille."
      }
    ],
    sections: ["466", "454"],
    demo: {
      title: "Attaque insuffisante : retour à la base",
      frames: [
        {
          caption: "Vous attaquez le champ avec 2 + 1 de puissance ; le défenseur a 4.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "a1", type: "unit", x: 42, y: 52, n: 2 },
            { k: "a2", type: "unit", x: 58, y: 52, n: 1 },
            { k: "d", type: "unit", side: "foe", x: 50, y: 26, n: 4 },
            { k: "base", type: "zone", x: 50, y: 88, label: "Votre base" }
          ]
        },
        {
          caption: "Dégâts : vos 3 ne tuent pas le défenseur (4). Ses 4 éliminent votre 2, votre 1 encaisse le reste.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "a1", type: "unit", x: 42, y: 52, n: 2, dead: true },
            { k: "a2", type: "unit", x: 58, y: 52, n: 1 },
            { k: "d", type: "unit", side: "foe", x: 50, y: 26, n: 4 },
            { k: "dmg", type: "chip", x: 50, y: 12, n: "3 < 4" },
            { k: "base", type: "zone", x: 50, y: 88, label: "Votre base" }
          ]
        },
        {
          caption: "Les deux camps ont des survivants : l'attaquant restant est RAPPELÉ à sa base.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "a2", type: "unit", x: 58, y: 88, n: 1 },
            { k: "d", type: "unit", side: "foe", x: 50, y: 26, n: 4 },
            { k: "base", type: "zone", x: 50, y: 88, label: "Votre base" }
          ]
        },
        {
          caption: "Aucun résultat : le défenseur garde le contrôle, tout le monde est soigné.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "a2", type: "unit", x: 58, y: 88, n: 1 },
            { k: "d", type: "unit", side: "foe", x: 50, y: 26, n: 4, glow: true },
            { k: "keep", type: "label", x: 50, y: 56, label: "Contrôle conservé", glow: true },
            { k: "base", type: "zone", x: 50, y: 88, label: "Votre base" }
          ]
        }
      ]
    }
  },
  {
    slug: "combat-multijoueur",
    title: "Combat à 3 ou 4 joueurs",
    category: "combat",
    summary: "Un combat n'implique que deux joueurs ; les autres ne peuvent pas s'y inviter.",
    details: [
      "Quel que soit le nombre de joueurs, un combat oppose toujours **exactement deux joueurs** : celui qui conteste et celui qui défendait.",
      "Un champ de bataille où un combat est **préparé ou en cours** entre deux autres joueurs est une **destination interdite** : ni déplacement standard, ni déplacement par effet, ni unité jouée dessus.",
      "Si un effet forçait une unité tierce à y être jouée, elle est jouée dans la **base** de son contrôleur à la place — et les parties de l'effet devenues invalides sont ignorées.",
      "Tous les choix qui aboutiraient à un combat à plus de deux joueurs sont tout simplement **invalides** : impossible de les prendre."
    ],
    cases: [
      {
        q: "Deux adversaires se battent sur un champ. Puis-je y envoyer une unité pour ramasser la conquête ?",
        a: "Non : tant que le combat est préparé ou en cours, ce champ est une destination non valide pour vous."
      },
      {
        q: "Le combat est fini, les survivants du vainqueur restent. Puis-je attaquer maintenant ?",
        a: "Oui : une fois le combat résolu, le champ redevient une destination valide — votre arrivée le contestera et déclenchera un nouveau combat contre le vainqueur."
      },
      {
        q: "Un troisième joueur peut-il jouer des sorts pendant le combat des deux autres ?",
        a: "Pendant la confrontation, la focalisation circule entre tous les joueurs dans l'ordre du tour : il peut jouer ses Actions/Réactions, mais ses unités ne peuvent pas rejoindre le champ."
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
      "Les champs de bataille sont l'unique source régulière de points. Deux façons de marquer, aux timings très différents.",
      "**Conquête** : au moment précis où vous prenez le contrôle d'un champ de bataille (fin de confrontation ou de combat), vous marquez **1 point immédiatement** — à condition que ce champ ne vous ait pas déjà rapporté de point pendant ce tour.",
      "**Occupation** : au début de **votre** tour, à l'étape des scores, chaque champ de bataille encore sous votre contrôle vous rapporte **1 point**. Tenir ses positions rapporte donc un revenu passif.",
      "Verrou universel : **un même champ de bataille ne peut vous rapporter qu'un point par tour**, toutes sources confondues — conquête, occupation ou effet.",
      "Les compétences imprimées sur les champs (« quand vous conquérez ici… », « quand vous occupez ici… ») se déclenchent uniquement quand le point correspondant est marqué : elles suivent la même limite d'une fois par tour et par joueur."
    ],
    cases: [
      {
        q: "Je conquiers un champ, je le perds, je le reprends dans le même tour. Deux points ?",
        a: "Non : un champ ne peut vous rapporter qu'un point par tour, quelle que soit la façon dont vous le regagnez."
      },
      {
        q: "Je conquiers un champ pendant le tour de l'adversaire (grâce à Embuscade ou un effet). Point ?",
        a: "Oui : la conquête marque à la prise de contrôle, peu importe le joueur du tour — toujours dans la limite d'un point par champ et par tour."
      },
      {
        q: "L'adversaire me prend mon champ puis je le reconquiers le même tour : lui et moi marquons ?",
        a: "Oui, chacun sa conquête : la limite d'un point par champ et par tour s'applique par joueur."
      },
      {
        q: "Je conquiers au tour 3 ; au tour 4 je contrôle toujours le champ. Combien de points ?",
        a: "1 point à la conquête (tour 3) + 1 point d'occupation au début de votre tour 4. C'est le cycle normal : conquérir, puis toucher l'occupation tant que vous tenez."
      }
    ],
    sections: ["467", "193"],
    demo: {
      title: "Conquête immédiate, occupation au tour suivant",
      frames: [
        {
          caption: "Votre unité prend le contrôle du champ : CONQUÊTE, +1 point immédiatement.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "u", type: "unit", x: 50, y: 40, n: 3 },
            { k: "pt", type: "chip", x: 72, y: 20, n: "+1 conquête", ok: true }
          ]
        },
        {
          caption: "Le tour de l'adversaire passe… vous tenez toujours le champ.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "u", type: "unit", x: 50, y: 40, n: 3 },
            { k: "t", type: "label", x: 50, y: 80, label: "Tour adverse" }
          ]
        },
        {
          caption: "Début de VOTRE tour, étape des scores : OCCUPATION, +1 point.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Champ de bataille" },
            { k: "u", type: "unit", x: 50, y: 40, n: 3, glow: true },
            { k: "pt2", type: "chip", x: 72, y: 20, n: "+1 occupation", ok: true },
            { k: "t", type: "label", x: 50, y: 80, label: "Votre tour — étape des scores" }
          ]
        }
      ]
    }
  },
  {
    slug: "dernier-point",
    title: "Le point de la victoire",
    category: "points",
    summary: "Finir par conquête exige d'avoir marqué sur chaque champ ce tour-là ; l'occupation n'a pas cette limite.",
    details: [
      "Le dernier point est spécial : quand une **conquête** vous amènerait au score de la victoire (8 en duel), elle ne compte que si vous avez marqué un point sur **chaque champ de bataille** pendant ce tour.",
      "Si la condition n'est pas remplie, le point de conquête est remplacé : vous **piochez une carte** à la place. Le champ est quand même conquis — seul le point est refusé.",
      "En duel : finir par conquête signifie marquer sur les **2 champs dans le même tour** (par exemple occuper l'un au début du tour, puis conquérir l'autre).",
      "Les points d'**occupation** et les points donnés par des **effets de cartes** ne subissent aucune restriction : ils peuvent vous faire gagner à tout moment de vérification.",
      "La victoire elle-même se vérifie au nettoyage : il faut atteindre le score ET avoir strictement plus de points que chaque adversaire (une égalité à 8 prolonge la partie)."
    ],
    cases: [
      {
        q: "7 points, je conquiers un seul champ ce tour : victoire ?",
        a: "Non — vous n'avez pas marqué sur chaque champ ce tour-là. Vous piochez une carte à la place, et restez à 7 (le champ est tout de même à vous)."
      },
      {
        q: "7 points, j'occupe mon champ au début de mon tour : victoire ?",
        a: "Oui : l'occupation n'a aucune restriction. 8 points, la partie se termine au nettoyage suivant."
      },
      {
        q: "7 points, j'occupe le champ A puis je conquiers le champ B le même tour ?",
        a: "Victoire : vous avez marqué sur chaque champ pendant ce tour, le point de conquête est accordé."
      },
      {
        q: "7-7, j'atteins 8 mais l'adversaire aussi (exténuation). Qui gagne ?",
        a: "Personne pour l'instant : il faut plus de points que tout adversaire. La partie continue jusqu'à ce qu'un nettoyage constate un écart."
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
      "Arriver sur un champ de bataille qu'on ne contrôle pas ne le vole pas : cela le rend **contesté**. Le contrôle ne change qu'à l'**issue** de la confrontation ou du combat qui suit.",
      "Vous **gardez** le contrôle tant que vous avez des unités sur le champ. Si votre dernière unité le quitte ou meurt (hors combat en cours), vous perdez le contrôle au **prochain nettoyage** — le champ devient non contrôlé.",
      "Un champ contrôlé mais momentanément vide reste à vous jusqu'à ce nettoyage : ses compétences fonctionnent encore, mais l'adversaire peut venir le conquérir sans combat.",
      "Pendant qu'une confrontation ou un combat est en cours sur un champ, son contrôle est **gelé** : il ne change que selon les étapes du combat.",
      "Le statut « contesté » sert au moteur du jeu (déclencher les confrontations) : aucun effet de carte n'y fait référence directement."
    ],
    cases: [
      {
        q: "Ma dernière unité du champ meurt pendant mon tour. Je perds le contrôle tout de suite ?",
        a: "Au prochain nettoyage (hors combat/confrontation en cours). D'ici là, les compétences du champ répondent encore à vous."
      },
      {
        q: "L'adversaire arrive sur mon champ contrôlé : je perds le contrôle ?",
        a: "Pas encore : le champ devient contesté, un combat s'engage (vos unités y sont). Le contrôle ne bascule qu'à la résolution."
      },
      {
        q: "Mon champ est vide mais encore à moi ; l'adversaire y entre. Combat ?",
        a: "Non, il n'y a pas d'unités à vous : confrontation sans combat, à l'issue de laquelle il prend le contrôle et conquiert."
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
      "Chaque champ de bataille imprime des compétences (passives, déclenchées ou activées). Le joueur qui **contrôle le champ** contrôle aussi ses compétences : il les met dans la chaîne et prend toutes les décisions associées.",
      "Dans le texte d'un champ, « **vous** » désigne son contrôleur actuel. Champ **non contrôlé** : « vous » ne désigne personne et ces instructions sont ignorées ; les autres compétences sont gérées par le joueur du tour.",
      "Les compétences « **quand vous conquérez ici** » et « **quand vous occupez ici** » ne se déclenchent qu'au moment où un **point** y est marqué : au plus une fois par tour et par joueur — pas de double déclenchement en reprenant le champ.",
      "Les champs de bataille ne sont ni des permanents ni des cartes du deck : ils ne peuvent être ni éliminés ni déplacés, et restent en place toute la partie."
    ],
    cases: [
      {
        q: "Le champ dit « quand vous conquérez ici, piochez 1 ». Je le conquiers une 2e fois dans le tour ?",
        a: "Pas de déclenchement : la compétence ne s'active que quand un point est marqué, donc au plus une fois par tour et par joueur."
      },
      {
        q: "Le champ adverse a une compétence activée. Puis-je l'utiliser ?",
        a: "Non : ses compétences appartiennent à son contrôleur. Prenez le contrôle du champ pour en profiter."
      },
      {
        q: "Une compétence du champ que je contrôle dit « piochez 1 » sans préciser qui. Qui pioche ?",
        a: "Vous : le « vous » implicite des instructions désigne le contrôleur du champ."
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
      "Un deck complet comprend quatre blocs : le **deck principal**, le **deck de runes**, une **légende de champion** et des **champs de bataille**.",
      "**Deck principal** : 40 cartes minimum (pas de maximum), dont votre **champion élu** — une unité champion portant le même tag que votre légende. Maximum **3 exemplaires** d'un même nom, champion élu inclus.",
      "**Cartes signatures** : maximum 3 dans le deck, toutes du tag de champion de votre légende.",
      "**Identité de domaine** : votre légende définit les domaines autorisés. Chaque carte du deck principal et chaque rune doit y entrer ; une carte multi-domaines exige que TOUS ses domaines soient couverts.",
      "**Deck de runes** : exactement **12 runes**. **Champs de bataille** : 3 en construction (1 seul sera présenté en duel), sans doublon de nom, soumis à l'identité de domaine le cas échéant.",
      "Le mot-clé [Unique] réduit la limite d'une carte à 1 exemplaire."
    ],
    cases: [
      {
        q: "Ma légende est Fureur/Chaos. Puis-je jouer une carte Fureur/Calme ?",
        a: "Non : une carte multi-domaines exige que TOUS ses domaines figurent dans l'identité de votre légende — Calme n'y est pas."
      },
      {
        q: "Puis-je mettre 3 champs de bataille identiques ?",
        a: "Non : aucun doublon de nom parmi vos champs de bataille."
      },
      {
        q: "Mon champion élu compte-t-il dans la limite de 3 exemplaires ?",
        a: "Oui : champion élu inclus, jamais plus de 3 cartes du même nom dans le deck principal."
      },
      {
        q: "Puis-je jouer plus de 40 cartes ?",
        a: "Oui, 40 est un minimum — mais plus le deck est gros, moins vous piochez vos meilleures cartes."
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
      "Le coût d'une carte se lit en haut à gauche : un **chiffre** à payer en énergie, et parfois des **symboles de domaine** à payer en essence runique — [R] [G] [B] [O] [P] [Y].",
      "Une rune de base offre deux compétences, toutes deux [Réaction] : **l'épuiser** ([E]) pour ajouter +[1], ou **la recycler** — la placer sous votre deck de runes (règle 416) — pour ajouter 1 essence de son domaine.",
      "[Réaction] signifie : utilisables à l'instant précis où un coût doit être payé — pendant votre tour, pendant une confrontation, même pendant le tour adverse.",
      "Tout ce que produisent vos runes va dans votre **réserve runique**… qui se **vide** au début de chaque phase principale et à la fin de chaque tour : impossible de stocker, on produit ce qu'on dépense à l'instant.",
      "Les runes canalisées **restent en zone de runes** de tour en tour et se redressent à votre éveil : le moteur grandit de 2 runes par tour. Recycler est donc un vrai coût : la rune quitte la table temporairement.",
      "Certaines essences sont **universelles** ([C]) et paient n'importe quel symbole de domaine."
    ],
    cases: [
      {
        q: "Puis-je recycler une rune épuisée ?",
        a: "Oui : recycler n'exige pas que la rune soit préparée — le coût est « recyclez ceci », indépendant de l'état épuisé/préparé."
      },
      {
        q: "Il me reste 2 énergies non dépensées en fin de phase. Je les garde ?",
        a: "Non : la réserve runique se vide, tout ce qui n'est pas dépensé est perdu. Ne produisez que ce que vous dépensez."
      },
      {
        q: "Puis-je payer un symbole de domaine avec de l'énergie ?",
        a: "Non, jamais : l'énergie paie les chiffres, l'essence paie les symboles. Dans l'autre sens non plus."
      },
      {
        q: "L'essence universelle, ça existe ?",
        a: "Oui : certaines essences sont universelles et paient n'importe quel symbole de domaine (règle 163.2.b) — l'icône [C]."
      },
      {
        q: "Une rune recyclée est-elle perdue pour la partie ?",
        a: "Non : elle est placée sous votre deck de runes et reviendra en jeu quand la canalisation l'atteindra."
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
      "Une unité se joue dans votre **base** et arrive **épuisée** — elle ne peut ni se déplacer ni payer de coût d'épuisement avant votre prochain éveil. Deux exceptions imprimées : [Accélération] (payer pour arriver préparée) et [Embuscade] (arriver directement sur un champ de bataille).",
      "Le **déplacement standard** est la compétence innée de toute unité : **épuisez-la** pour aller de la base vers un champ de bataille, ou en revenir. Jamais de champ à champ — sauf [Gank].",
      "Plusieurs unités peuvent se déplacer **ensemble** en une seule action, à condition d'avoir la même destination (pas forcément le même point de départ).",
      "Timing du déplacement : uniquement pendant votre phase principale, dans un état ouvert — jamais pendant une confrontation ou un combat.",
      "Les **dégâts** se marquent sur l'unité et y restent jusqu'au prochain soin (fin de tour ou nettoyage de combat). Dès qu'un nettoyage constate des dégâts marqués ≥ puissance actuelle, l'unité est éliminée et va à la défausse de son propriétaire."
    ],
    cases: [
      {
        q: "Puis-je déplacer une unité pendant une confrontation ?",
        a: "Non : le déplacement standard est interdit pendant les confrontations et les combats, et pendant tout état fermé."
      },
      {
        q: "Deux unités partent de deux endroits différents vers le même champ : un seul déplacement ?",
        a: "Oui : le déplacement simultané exige la même destination, pas le même point de départ. Les coûts d'épuisement se paient ensemble."
      },
      {
        q: "Mon unité a 2 dégâts et une puissance de 3 ; un malus la passe à 2 de puissance. Elle meurt ?",
        a: "Oui, au prochain nettoyage : ses dégâts marqués (2) atteignent sa puissance actuelle (2) — dégâts mortels."
      },
      {
        q: "Une unité peut-elle attaquer le tour où elle arrive ?",
        a: "Seulement si elle est entrée préparée ([Accélération]) ou directement sur le champ ([Embuscade]). Sinon, elle attend votre prochain éveil."
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
      "Un **équipement** se joue dans votre base et, contrairement aux unités, arrive **préparé** : ses compétences activées sont utilisables immédiatement.",
      "Les équipements portant le tag **Objet** s'attachent aux unités : la carte du dessus (l'unité) gagne le texte d'effet et le **bonus de puissance** de l'objet ; la description imprimée de l'objet devient inactive tant qu'il est porté.",
      "[Équiper] est une compétence activée « [Coût] : équipez à une unité que vous contrôlez » — phase principale, état ouvert. [Dégainer] équipe immédiatement l'objet quand il est joué, avec les permissions d'une [Réaction].",
      "Équiper un objet déjà porté à une **nouvelle** unité le déséquipe automatiquement de l'ancienne (règle 434.1.f) : re-payer le coût d'Équiper suffit pour le faire circuler.",
      "Un équipement non porté ne peut pas rester sur un champ de bataille : au nettoyage, il est rappelé dans la base de son contrôleur. Porté, il suit son unité partout."
    ],
    cases: [
      {
        q: "Mon unité équipée meurt. L'objet aussi ?",
        a: "Non : l'objet se retrouve simplement non porté ; s'il est sur un champ de bataille, il est rappelé à votre base au nettoyage."
      },
      {
        q: "Puis-je équiper un objet à une unité adverse ?",
        a: "Non : [Équiper] cible une unité que VOUS contrôlez."
      },
      {
        q: "Le bonus de puissance de l'objet compte-t-il dans les dégâts de combat ?",
        a: "Oui : la puissance de l'unité équipée est modulée par le bonus — il compte dans le total du camp et dans son seuil de dégâts mortels."
      },
      {
        q: "Puis-je équiper en pleine confrontation ?",
        a: "Pas via [Équiper] (compétence de phase principale) — mais [Dégainer] le permet : jouer l'objet en Réaction l'attache immédiatement."
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
      "La **légende de champion** n'est jamais mélangée au deck : posée dans sa zone dès la mise en place, elle y reste toute la partie — impossible de l'éliminer, de la déplacer ou de la cibler hors des cas prévus par les effets.",
      "Ses compétences fonctionnent en continu : passives (toujours actives), déclenchées (elles partent seules) ou activées (« [Coût] : effet », à payer comme un sort).",
      "Le **champion élu** est une carte du deck principal mise à part au début : visible dans sa zone dédiée, il se joue exactement comme s'il était dans votre main — mêmes coûts, mêmes fenêtres de timing.",
      "Une fois qu'il a quitté sa zone (joué, puis éventuellement éliminé ou défaussé), il suit les règles des cartes normales : direction la défausse, pas de retour en zone de champion.",
      "La légende définit aussi l'**identité de domaine** de tout votre deck — voyez « Construire un deck légal »."
    ],
    cases: [
      {
        q: "Mon champion élu est éliminé. Puis-je le rejouer depuis sa zone ?",
        a: "Non : il va à la défausse comme n'importe quelle unité. La zone de champion ne sert qu'au départ."
      },
      {
        q: "La compétence de ma légende coûte « [E] : effet ». Quand puis-je l'activer ?",
        a: "Comme une compétence activée : pendant votre phase principale, état ouvert, hors confrontation — sauf si elle porte [Action] ou [Réaction]."
      },
      {
        q: "Un sort adverse peut-il éliminer ma légende ?",
        a: "Non : les légendes ne peuvent pas être éliminées ni déplacées (règles 174.3-174.4). Elles peuvent seulement être ciblées quand un effet le prévoit (épuisement, etc.)."
      },
      {
        q: "Si j'ai 3 exemplaires de mon champion en deck plus le champion élu ?",
        a: "Illégal : la limite de 3 par nom inclut le champion élu — 2 en deck + l'élu au maximum."
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
      "**Règle d'or** : ce qui est inscrit sur une carte a priorité sur les règles du jeu. Si une carte contredit le livre, la carte gagne.",
      "**Règle d'argent** : la terminologie des cartes n'est pas celle du livre. Dans un texte de carte, « **carte** » = carte du deck principal — les runes, légendes et champs de bataille n'en sont pas.",
      "Les cartes parlent d'elles-mêmes à la première personne : les unités disent « je », les sorts et équipements « ceci », les champs de bataille « ici ».",
      "Les **interdictions** l'emportent sur les autorisations : « ne peut pas » bat « peut ». Et « ne … que » exclut toutes les autres circonstances.",
      "Lors de l'exécution d'une carte : faites tout ce qui est possible, ignorez l'impossible. Si rien n'est réalisable, la carte est quand même considérée comme jouée et résolue."
    ],
    cases: [
      {
        q: "Un effet dit « détruisez une carte » : puis-je viser une rune ?",
        a: "Non : dans les textes de cartes, « carte » = carte du deck principal. Les runes n'en font pas partie (règle d'argent)."
      },
      {
        q: "Une carte m'autorise un déplacement, une autre me l'interdit. Qui gagne ?",
        a: "L'interdiction : les cartes qui interdisent prévalent sur celles qui autorisent."
      },
      {
        q: "Une instruction de ma carte est irréalisable. La carte échoue ?",
        a: "Non : exécutez le réalisable, ignorez le reste. Même tout irréalisable, la carte est considérée jouée et résolue — les coûts restent payés."
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
      "Texte complet : « Quand vous me jouez, vous pouvez payer un coût supplémentaire de [1] plus 1 essence de mon domaine. Si vous le faites, j'entre en jeu préparé. »",
      "Le choix se fait **au moment de jouer** l'unité, jamais après : c'est un coût supplémentaire ajouté au coût normal, payé en même temps.",
      "L'essence du coût d'Accélération doit correspondre à un **domaine de l'unité** (une essence universelle convient aussi).",
      "Une unité entrée **préparée** agit immédiatement : déplacement standard vers un champ de bataille, coûts d'épuisement, tout est permis.",
      "Même si l'unité perd le mot-clé pendant qu'elle est jouée, le coût payé garantit l'entrée préparée (effet de remplacement différé, règle 805.2.b)."
    ],
    cases: [
      {
        q: "Puis-je payer l'Accélération plus tard dans le tour ?",
        a: "Non : c'est un coût additionnel payé au moment où vous jouez l'unité, ou jamais."
      },
      {
        q: "Accélération + Embuscade : l'unité peut-elle arriver préparée sur un champ de bataille ?",
        a: "Oui, en payant les deux : Embuscade autorise l'emplacement, l'Accélération l'état préparé."
      },
      {
        q: "Mon unité Fureur/Chaos : quelle essence pour l'Accélération ?",
        a: "Fureur OU Chaos (un de ses domaines), ou une essence universelle."
      },
      {
        q: "L'adversaire peut-il savoir si j'ai payé l'Accélération ?",
        a: "Oui : les coûts payés sont publics, et l'unité entre visiblement préparée au lieu d'épuisée."
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
      "Par défaut, un sort sans mot-clé ne se joue que pendant votre phase principale, hors confrontation, chaîne vide. [Action] élargit cette fenêtre.",
      "Un sort [Action] se joue aussi dans les **états ouverts des confrontations** — y compris les confrontations qui se déroulent pendant le tour adverse.",
      "C'est le cœur du jeu de combat : pendant une confrontation, seuls les sorts [Action] et [Réaction] peuvent intervenir.",
      "[Action] apparaît sur des sorts, mais aussi sur des compétences de runes, de légendes et de permanents — mêmes permissions."
    ],
    cases: [
      {
        q: "L'adversaire m'attaque pendant son tour. Puis-je jouer un sort Action ?",
        a: "Oui, pendant la confrontation de combat, quand vous avez la focalisation et que l'état est ouvert."
      },
      {
        q: "Puis-je jouer une Action en réponse au sort de l'adversaire ?",
        a: "Non : répondre à un objet dans la chaîne exige [Réaction] — l'état est fermé tant que la chaîne n'est pas vide."
      },
      {
        q: "Action se joue-t-il pendant le tour adverse hors confrontation ?",
        a: "Non : hors confrontation, le tour adverse ne vous offre aucune fenêtre. Il faut une confrontation ouverte."
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
      "[Réaction] = toutes les permissions d'[Action], **plus les états fermés** : jouable en réponse à un sort ou une compétence déjà dans la chaîne, avant sa résolution.",
      "Un sort [Réaction] s'empile au-dessus et se résout **avant** les objets déjà en attente.",
      "Les compétences des runes (« Ajoutez [1] », « Ajoutez 1 essence ») sont des [Réaction] : c'est pourquoi vous pouvez produire des ressources à l'instant exact où un coût se présente, même hors de votre tour.",
      "Une Réaction reste soumise au système de focalisation pendant les confrontations : vous la jouez quand une fenêtre s'ouvre, pas à n'importe quel instant."
    ],
    cases: [
      {
        q: "L'adversaire cible mon unité avec un sort d'élimination. Ma Réaction la sauve-t-elle ?",
        a: "Si votre Réaction la retire du plateau ou invalide la cible avant la résolution, le sort adverse échouera sur cette cible."
      },
      {
        q: "Puis-je réagir à une Réaction ?",
        a: "Oui : les Réactions s'empilent les unes sur les autres. La dernière jouée se résout la première."
      },
      {
        q: "Puis-je jouer une Réaction pendant la phase de pioche adverse ?",
        a: "Seulement si quelque chose crée une fenêtre (un objet dans la chaîne, une confrontation). Les phases automatiques n'ouvrent pas de fenêtre en elles-mêmes."
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
      "Texte complet : « Tant que j'attaque, j'ai +X [M]. »",
      "La désignation **attaquant** s'obtient en combat, quand votre camp a contesté le champ : le bonus s'active à ce moment-là et disparaît à la fin du combat.",
      "Le bonus compte dans le **total de puissance** du camp à l'étape des dégâts ET dans le seuil de dégâts mortels de l'unité pendant le combat.",
      "Assaut ne fait rien en défense, ni hors combat — une unité Assaut posée en garnison est une unité ordinaire."
    ],
    cases: [
      {
        q: "Assaut compte-t-il quand je défends mon champ de bataille ?",
        a: "Non : le bonus n'existe que tant que l'unité a la désignation d'attaquant."
      },
      {
        q: "Assaut 2 sur une unité de puissance 3 : combien de dégâts pour la tuer quand elle attaque ?",
        a: "5 : sa puissance effective en attaque est 5, donc son seuil de dégâts mortels aussi."
      },
      {
        q: "Mon unité Assaut arrive sur le champ en cours de combat via un effet. Bonus ?",
        a: "Oui, dès qu'elle reçoit la désignation d'attaquant au nettoyage suivant son arrivée."
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
      "Texte complet : « Tant que je défends, j'ai +X [M]. »",
      "La désignation **défenseur** s'obtient quand votre champ contrôlé est contesté par l'adversaire : vos unités présentes deviennent défenseuses.",
      "Le bonus augmente le total de puissance du camp ET le **seuil de dégâts mortels** de l'unité — un Bouclier 1 sur une puissance 3 exige 4 dégâts en combat.",
      "Miroir exact d'[Assaut] : nul en attaque et hors combat, précieux en garnison."
    ],
    cases: [
      {
        q: "Bouclier 1 sur une unité de puissance 3 : combien de dégâts pour la tuer en combat ?",
        a: "4 en défense : la puissance effective monte à 4, donc le seuil de dégâts mortels aussi."
      },
      {
        q: "Un sort inflige 3 dégâts à mon unité Bouclier 1 (puissance 3) hors combat. Elle survit ?",
        a: "Non : hors combat elle n'est pas défenseuse, sa puissance reste 3 — les 3 dégâts sont mortels."
      },
      {
        q: "Bouclier aide-t-il pendant une confrontation sans combat ?",
        a: "Non : sans combat, pas de désignation de défenseur — le bonus reste inactif."
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
      "Texte : les dégâts mortels doivent être attribués au [Tank] avant toute autre unité du même camp sans [Tank], pendant l'étape des dégâts de combat.",
      "C'est une contrainte imposée à **l'adversaire qui attribue** : il ne peut pas contourner votre Tank pour exécuter vos unités fragiles.",
      "Ne s'applique **qu'aux dégâts de combat** : un sort ou une compétence vise librement n'importe quelle unité.",
      "Plusieurs Tanks dans le même camp : l'ordre entre eux est libre, mais tous doivent recevoir des dégâts mortels avant les non-Tanks.",
      "Combiné à [Bouclier], le Tank devient un mur : il force les dégâts sur lui ET les encaisse mieux."
    ],
    cases: [
      {
        q: "Puis-je « sauter » un Tank que je ne peux pas tuer ?",
        a: "Non : sans dégâts mortels attribués au Tank, aucune autre unité ne peut en recevoir. Vos dégâts partent dessus, même en pure perte."
      },
      {
        q: "Tank protège-t-il contre un sort de dégâts ?",
        a: "Non : Tank ne contraint que l'attribution des dégâts de combat."
      },
      {
        q: "Tank et Arrière-ligne sur la même unité ?",
        a: "Exigences exclusives : le joueur qui attribue choisit UNE des deux à appliquer (règle 465.2.c.8)."
      },
      {
        q: "Le Tank est déjà blessé : dois-je quand même l'achever en premier ?",
        a: "Oui, mais les dégâts déjà marqués comptent : il ne vous faut que le complément pour atteindre sa puissance."
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
      "L'inverse exact de [Tank] : cette unité ne peut recevoir de dégâts de combat mortels qu'après **toutes** les autres unités du même camp sans [Arrière-ligne].",
      "Parfait pour protéger une unité à effet (déclencheurs, compétences activées) derrière des corps plus sacrifiables.",
      "À priorité égale (plusieurs Arrière-lignes), l'ordre entre elles est au choix du joueur qui attribue.",
      "Comme Tank : aucune protection contre les sorts et compétences — seulement contre l'attribution en combat."
    ],
    cases: [
      {
        q: "Arrière-ligne + Tank sur la même unité : que se passe-t-il ?",
        a: "Exigences exclusives : le joueur qui attribue choisit UNE des deux compétences à appliquer (règle 465.2.c.8)."
      },
      {
        q: "L'adversaire a assez de dégâts pour tout tuer. Mon Arrière-ligne survit ?",
        a: "Non : si son total couvre toutes vos unités, l'Arrière-ligne reçoit ses dégâts mortels en dernier — mais les reçoit."
      },
      {
        q: "Une seule unité en défense, avec Arrière-ligne. Protégée ?",
        a: "Non : « en dernier » ne veut rien dire quand elle est seule — elle reçoit les dégâts normalement."
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
      "Normalement, le déplacement standard relie la base et les champs de bataille — jamais deux champs entre eux. [Gank] lève cette limite.",
      "Une unité [Gank] peut, avec son déplacement standard habituel (s'épuiser), passer **directement d'un champ de bataille à un autre**.",
      "Toutes les autres restrictions demeurent : phase principale seulement, état ouvert, pas pendant une confrontation ou un combat, destination valide (pas de combat de deux autres joueurs en cours).",
      "Stratégiquement : le Gank menace les deux champs à la fois — l'adversaire doit défendre partout."
    ],
    cases: [
      {
        q: "Mon unité Gank est sur un champ contesté. Peut-elle fuir vers l'autre champ ?",
        a: "Non si une confrontation ou un combat y est en cours : le déplacement standard est interdit pendant ces phases."
      },
      {
        q: "Gank permet-il de traverser sans s'épuiser ?",
        a: "Non : c'est toujours le déplacement standard — épuiser l'unité reste le coût."
      },
      {
        q: "Puis-je faire base → champ A → champ B le même tour ?",
        a: "Non : chaque déplacement épuise l'unité. Un seul déplacement standard par éveil, sauf effet qui la re-prépare."
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
      "Double permission : « Je peux être joué sur un champ de bataille où vous contrôlez des unités » — au lieu de la base — et, jouée ainsi, l'unité bénéficie des permissions d'une [Réaction].",
      "Concrètement : en pleine confrontation, même pendant le tour adverse, vous pouvez faire surgir l'unité sur le champ pour renforcer votre camp.",
      "L'unité arrive **épuisée** (sauf [Accélération] payée en plus) — mais l'état épuisé n'empêche pas de compter dans les dégâts de combat.",
      "Elle reçoit sa désignation (attaquant/défenseur) au nettoyage suivant son arrivée et participera à l'étape des dégâts si elle est présente."
    ],
    cases: [
      {
        q: "Puis-je jouer une unité Embuscade au milieu d'un combat pour ajouter sa puissance ?",
        a: "Oui, si vous contrôlez déjà des unités sur ce champ : elle arrive (épuisée) et comptera dans les dégâts si elle est là à l'étape 2."
      },
      {
        q: "Embuscade sur un champ vide que je contrôle ?",
        a: "Non : il faut y contrôler des UNITÉS, pas seulement le champ."
      },
      {
        q: "Embuscade dans la base ?",
        a: "Toujours possible : Embuscade est une permission supplémentaire, pas une obligation. Jouée en base, l'unité est normale (pas de Réaction)."
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
      "Payez le coût de [Caché] pour placer la carte **face cachée** dans la zone dédiée d'un champ de bataille que vous contrôlez — une seule carte par zone de face cachée.",
      "À partir de votre **tour suivant**, la carte gagne [Réaction] : jouez-la au meilleur moment en payant son coût normal — l'adversaire sait qu'une carte est là, pas laquelle.",
      "Si vous **perdez le contrôle** du champ, la carte cachée est retirée au prochain nettoyage — le piège saute.",
      "La zone de face cachée est publique (tout le monde voit qu'il y a une carte), le contenu est privé (vous seul le connaissez)."
    ],
    cases: [
      {
        q: "L'adversaire peut-il regarder ma carte cachée ?",
        a: "Non : la zone est publique, la carte est privée. Il sait qu'il y a une carte, pas laquelle."
      },
      {
        q: "Je perds le champ puis le reprends : ma carte cachée est-elle encore là ?",
        a: "Non, si un nettoyage a eu lieu entre-temps : elle est retirée dès que le contrôleur du champ ne correspond plus."
      },
      {
        q: "Puis-je jouer la carte cachée le tour où je l'ai posée ?",
        a: "Non : la permission Réaction ne s'active qu'à partir du tour suivant."
      },
      {
        q: "Deux cartes cachées sur le même champ ?",
        a: "Non : une zone de face cachée ne contient qu'une carte au maximum (sauf effet qui augmente la capacité)."
      }
    ],
    sections: ["811", "107"],
    examples: [
      {
        id: "ogn-121-298",
        name: "Teemo - Strategist",
        img: img("b05f31bf744972983f61a9f5801b4ffd68fb9ebf-744x1039.png")
      }
    ],
    demo: {
      title: "Caché : poser, attendre, surgir",
      frames: [
        {
          caption: "Votre tour : vous payez le coût de Caché et posez la carte FACE CACHÉE sur votre champ.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Votre champ de bataille" },
            { k: "u", type: "unit", x: 38, y: 40, n: 2 },
            { k: "c", type: "card", x: 62, y: 40, label: "?", glow: true }
          ]
        },
        {
          caption: "L'adversaire voit qu'une carte est là — sans savoir laquelle.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Votre champ de bataille" },
            { k: "u", type: "unit", x: 38, y: 40, n: 2 },
            { k: "c", type: "card", x: 62, y: 40, label: "?" },
            { k: "foe", type: "unit", side: "foe", x: 50, y: 12, n: 4 }
          ]
        },
        {
          caption: "Tour suivant : la carte gagne Réaction. L'adversaire attaque…",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Votre champ — contesté", hot: true },
            { k: "u", type: "unit", x: 38, y: 40, n: 2 },
            { k: "c", type: "card", x: 62, y: 40, label: "?" },
            { k: "foe", type: "unit", side: "foe", x: 50, y: 32, n: 4 }
          ]
        },
        {
          caption: "…vous la retournez en pleine confrontation, au moment parfait.",
          items: [
            { k: "bf", type: "zone", x: 50, y: 42, label: "Votre champ — contesté", hot: true },
            { k: "u", type: "unit", x: 38, y: 40, n: 2 },
            { k: "c", type: "card", x: 62, y: 40, label: "Surprise !", glow: true },
            { k: "foe", type: "unit", side: "foe", x: 50, y: 32, n: 4 }
          ]
        }
      ]
    }
  },
  {
    slug: "agonie",
    title: "Agonie",
    category: "mots-cles",
    summary: "« Lorsque je suis éliminé, [effet]. »",
    details: [
      "Compétence déclenchée à l'**élimination** du permanent, quelle que soit la cause : dégâts de combat, sort, coût payé, effet.",
      "L'effet s'ajoute à la chaîne après le nettoyage qui a constaté l'élimination, puis se résout normalement — l'adversaire peut y réagir.",
      "L'unité est déjà dans la défausse quand l'effet se résout : l'effet fonctionne quand même (il vient de la compétence, pas de l'unité en jeu).",
      "Sacrifier volontairement une unité Agonie (via un coût) déclenche bien l'effet : « éliminé » couvre toutes les éliminations."
    ],
    cases: [
      {
        q: "Mon unité Agonie meurt pendant l'étape des dégâts de combat. L'effet part quand ?",
        a: "Après le nettoyage de combat qui l'élimine — l'effet entre dans la chaîne et se résout avant la suite de la résolution du combat."
      },
      {
        q: "Deux unités Agonie meurent ensemble. Ordre des effets ?",
        a: "Leur contrôleur les ajoute à la chaîne dans l'ordre de son choix ; elles se résolvent en ordre inverse d'empilement."
      },
      {
        q: "Une unité Agonie bannie déclenche-t-elle son effet ?",
        a: "Non : bannir n'est pas éliminer — ce sont deux actions différentes."
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
      "Texte : « Au début de la phase de départ du joueur qui contrôle ce permanent, avant d'octroyer les points, éliminez cet élément. »",
      "Le timing est chirurgical : l'élimination arrive **avant l'étape des scores** — une unité Temporaire seule sur un champ ne vous fera PAS marquer l'occupation.",
      "Le permanent vit donc au mieux un tour complet : le vôtre (où il apparaît) plus le tour adverse.",
      "C'est une élimination : elle déclenche [Agonie] et les effets « quand une unité est éliminée »."
    ],
    cases: [
      {
        q: "Ma création Temporaire tient un champ de bataille. Vais-je marquer l'occupation ?",
        a: "Non : elle est éliminée avant l'octroi des points. Le champ reste peut-être à vous, mais vide — et prenable."
      },
      {
        q: "Une unité Temporaire volée à l'adversaire disparaît quand ?",
        a: "Au début de la phase de départ de son CONTRÔLEUR actuel — le timing suit le contrôle."
      },
      {
        q: "Temporaire + Agonie : l'effet d'Agonie se déclenche ?",
        a: "Oui : Temporaire élimine, et toute élimination déclenche Agonie."
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
      "**Prédire** : regardez la carte du dessus de votre deck principal ; laissez-la en place, ou recyclez-la (placée sous le deck).",
      "La condition de déclenchement est **l'entrée du permanent sur le plateau** (règle 817.1.c) — pas le simple fait d'être mis dans la chaîne.",
      "Plusieurs instances de Vision se déclenchent **séparément** : vous choisissez pour chacune de recycler ou non — sans recyclage entre-temps, elles verront la même carte.",
      "Vision lisse votre pioche : gardez la bonne carte pour la phase de pioche, envoyez la mauvaise au fond."
    ],
    cases: [
      {
        q: "Vision se déclenche-t-il si la carte est contrée ?",
        a: "Non : une carte contrée ne fait rien et n'entre pas sur le plateau (règle 425.1) — pas d'entrée, pas de prédiction."
      },
      {
        q: "Deux unités Vision jouées coup sur coup : je vois deux cartes ?",
        a: "Chaque Vision se déclenche séparément. Si vous ne recyclez pas la carte regardée, la seconde Vision verra la même carte."
      },
      {
        q: "Dois-je montrer la carte regardée à l'adversaire ?",
        a: "Non : prédire est privé — l'adversaire sait seulement que vous avez regardé."
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
      "Formulation : « [Légion] — [Texte] » : la carte gagne le texte si vous avez joué une **autre carte** pendant ce tour.",
      "« Jouer » au sens strict : cartes du deck principal (et champion élu). **Canaliser** des runes, activer des compétences ou déplacer des unités ne compte pas.",
      "La condition s'évalue au moment où la carte Légion se joue/résout : jouez d'abord la petite carte, puis la carte Légion.",
      "Le compte est remis à zéro à chaque tour — y compris pendant le tour adverse (une carte jouée en Réaction pendant son tour peut activer une Légion jouée dans la même fenêtre)."
    ],
    cases: [
      {
        q: "Une rune canalisée compte-t-elle comme « carte jouée » pour Légion ?",
        a: "Non : canaliser n'est pas jouer. Il faut avoir joué une carte du deck principal (ou le champion élu) ce tour."
      },
      {
        q: "L'ordre compte-t-il ? Légion d'abord, autre carte ensuite ?",
        a: "Oui, l'ordre compte : la condition se vérifie quand la carte Légion est jouée. Jouez l'autre carte AVANT."
      },
      {
        q: "Une carte contrée compte-t-elle pour Légion ?",
        a: "Non : une carte contrée n'est pas considérée comme ayant été jouée (règle 425.1.b)."
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
    chips: ["Niveau"],
    summary: "« Tant que vous avez N XP ou plus, cette carte a [Texte]. »",
    details: [
      "L'**XP** est un compteur propre à chaque joueur : il se gagne via des effets (dont [Chasse]) et ne se dépense que si un coût le demande.",
      "**Niveau N** : tant que votre total d'XP atteint N, la carte gagne le texte associé — c'est une compétence continue, elle s'allume et s'éteint avec votre total.",
      "Les effets Niveau s'appliquent partout où la carte se trouve si le texte le permet — la plupart concernent la carte en jeu.",
      "Construire autour : quelques sources d'XP fiables transforment toutes vos cartes à Niveau en versions améliorées."
    ],
    cases: [
      {
        q: "Je passe sous le seuil d'XP (un coût m'en fait dépenser). Le bonus Niveau disparaît ?",
        a: "Oui : Niveau est une compétence continue conditionnée à votre total d'XP actuel."
      },
      {
        q: "L'XP se partage-t-elle entre mes cartes ?",
        a: "L'XP appartient au joueur, pas à la carte : toutes vos cartes Niveau lisent le même total."
      },
      {
        q: "L'XP disparaît-elle en fin de tour ?",
        a: "Non : l'XP est un compteur durable — il ne se vide pas comme la réserve runique."
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
      "Texte : « Lorsque je conquiers ou que j'occupe, le joueur qui me contrôle gagne X XP. »",
      "« Je conquiers / j'occupe » : l'unité doit être sur le champ de bataille au moment où le point de conquête ou d'occupation y est marqué.",
      "Chaque unité Chasse présente déclenche sa propre instance : deux Chasse sur le champ = deux gains d'XP.",
      "Moteur naturel des decks à [Niveau] : tenir les champs nourrit l'XP, l'XP améliore les cartes."
    ],
    cases: [
      {
        q: "Deux unités Chasse sur le même champ quand je marque : double XP ?",
        a: "Oui : chaque compétence Chasse se déclenche séparément et donne son XP."
      },
      {
        q: "Mon unité Chasse est en base quand j'occupe le champ. XP ?",
        a: "Non : c'est l'unité qui doit conquérir/occuper — elle doit être sur le champ concerné."
      },
      {
        q: "Le point de conquête est remplacé par une pioche (dernier point). Chasse se déclenche ?",
        a: "Non : les compétences liées au point ne s'activent que quand un point est effectivement marqué."
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
    chips: ["Amplification", "Amplifié"],
    summary: "Payez une fois pour amplifier le permanent ; tant qu'il l'est, il gagne le texte Amplifié.",
    details: [
      "[Amplification] est une compétence activée : « [Coût] : amplifiez ceci » — utilisable seulement si le permanent n'est **pas déjà amplifié**.",
      "[Amplifié] est l'état résultant : « tant que je suis amplifié, cette carte gagne [Texte] » — un état **durable**, pas un effet de tour.",
      "L'amplification survit à la fin du tour et aux combats : elle ne disparaît que si le permanent quitte le plateau (ou qu'un effet la retire).",
      "Un seul passage : impossible d'amplifier deux fois le même permanent pour cumuler."
    ],
    cases: [
      {
        q: "L'état amplifié disparaît-il en fin de tour ?",
        a: "Non : c'est un état durable du permanent, il persiste tant que le permanent reste en jeu."
      },
      {
        q: "Mon unité amplifiée meurt et revient en jeu. Encore amplifiée ?",
        a: "Non : revenir en jeu est un nouvel objet — l'état amplifié est perdu, il faudra re-payer."
      },
      {
        q: "Quand puis-je activer l'Amplification ?",
        a: "Comme toute compétence activée : votre phase principale, état ouvert, hors confrontation — sauf mention Action/Réaction."
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
      "Texte : chaque fois qu'un sort ou une compétence contrôlé par un **adversaire** choisit cette carte, son coût augmente de X **essence runique**.",
      "La taxe se paie en essence — la ressource chère : l'adversaire devra recycler des runes ou mobiliser ses producteurs d'essence.",
      "Vos propres sorts ne sont pas taxés : Protection ne gêne jamais son propriétaire.",
      "Les effets **sans ciblage** (« toutes les unités », dégâts de combat, auras globales) ignorent complètement la Protection."
    ],
    cases: [
      {
        q: "Un sort adverse qui touche « toutes les unités » paie-t-il la Protection ?",
        a: "Non : sans ciblage, pas de surcoût. Protection ne taxe que les sorts et compétences qui choisissent la carte."
      },
      {
        q: "L'adversaire cible ma carte Protection 2 avec un sort qui coûte déjà 1 essence. Total ?",
        a: "1 + 2 = 3 essences (plus le coût en énergie du sort) : les surcoûts s'additionnent au coût imprimé."
      },
      {
        q: "Un sort qui cible DEUX de mes cartes Protection 1 chacune ?",
        a: "Chaque choix taxe : +1 par carte Protection choisie, soit +2 essences au total."
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
      "Texte : « Quand vous jouez ceci, vous pouvez payer un coût supplémentaire de [Coût]. Si vous le faites, exécutez les instructions de cet objet une fois de plus lors de la résolution. »",
      "Le choix et le paiement se font **au moment de jouer** la carte — comme l'Accélération, jamais après coup.",
      "À la résolution, les instructions s'exécutent deux fois de suite, intégralement : première passe complète, puis seconde passe.",
      "Les nouveaux choix ouverts par la seconde exécution sont refaits (cibles comprises, si la formulation de la carte le permet — voir règle 750 sur les nouveaux choix)."
    ],
    cases: [
      {
        q: "Puis-je choisir deux cibles différentes pour les deux exécutions ?",
        a: "Selon la formulation : si la cible se choisit dans les instructions, la seconde passe refait le choix. Si la cible est unique au moment de jouer, elle reste."
      },
      {
        q: "L'adversaire contre mon sort Répétition payé. Remboursé ?",
        a: "Non : contrer ne rembourse aucun coût, supplémentaires compris (règle 425.1.c)."
      },
      {
        q: "Répétition double-t-elle aussi les mots-clés du sort ?",
        a: "Non : seules les INSTRUCTIONS sont ré-exécutées — les propriétés du sort ne changent pas."
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
      "Texte : « Vous pouvez jouer ceci de votre défausse pour son coût de flux. Puis bannissez-le. »",
      "Le **coût de flux** est un coût alternatif imprimé, souvent différent du coût normal — il ne s'applique que depuis la défausse.",
      "Après la résolution depuis la défausse, la carte est **bannie** : direction la zone de bannissement, pas de boucle infinie.",
      "Défausser une carte Flux n'est donc pas la perdre : votre défausse devient une seconde main."
    ],
    cases: [
      {
        q: "Puis-je jouer la carte depuis la main ET depuis la défausse ?",
        a: "Oui : depuis la main au coût normal (elle va en défausse après), puis depuis la défausse au coût de flux (elle est bannie après)."
      },
      {
        q: "Le timing change-t-il depuis la défausse ?",
        a: "Non : mêmes fenêtres que d'habitude — et les mots-clés Action/Réaction de la carte s'appliquent aussi depuis la défausse."
      },
      {
        q: "Une carte Flux contrée depuis la défausse est-elle bannie ?",
        a: "Elle est retirée de la chaîne vers la défausse (règle 425.1.a.1) — le bannissement de Flux suit la résolution, qui n'a pas eu lieu."
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
    chips: ["Équiper", "Dégainer"],
    summary: "Équiper : compétence activée d'attache. Dégainer : équipe immédiatement, en Réaction.",
    details: [
      "[Équiper] est une compétence activée des Objets : « [Coût] : équipez cet équipement à une unité que vous contrôlez » — phase principale, état ouvert.",
      "[Dégainer] combine deux choses : la carte se joue avec les permissions d'une [Réaction], ET s'équipe immédiatement à une unité que vous contrôlez en entrant en jeu.",
      "L'unité équipée (carte du dessus) gagne le texte d'effet et le bonus de puissance de l'objet ; la description imprimée de l'objet est inactive tant qu'il est porté.",
      "Ré-équiper : payer à nouveau le coût d'Équiper vers une autre unité déséquipe automatiquement l'objet de l'ancienne (règle 434.1.f)."
    ],
    cases: [
      {
        q: "Puis-je ré-équiper un objet d'une unité à une autre ?",
        a: "Oui, en payant à nouveau son coût d'Équiper : l'objet se détache et s'attache à la nouvelle unité."
      },
      {
        q: "Dégainer en pleine confrontation : le bonus compte pour les dégâts ?",
        a: "Oui : joué en Réaction et équipé aussitôt, le bonus de puissance compte si l'unité est présente à l'étape des dégâts."
      },
      {
        q: "L'unité porteuse meurt : l'objet est-il éliminé ?",
        a: "Non : il devient non porté ; sur un champ de bataille, il est rappelé à votre base au nettoyage."
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
      "Texte : « Lorsque vous me jouez, vous pouvez choisir une carte Objet que vous contrôlez ; payez son coût d'Équiper réduit de [X] pour l'équiper à cette unité. »",
      "Le déclencheur part quand l'unité est jouée : vous choisissez un Objet déjà sur la table (porté ou non) et payez le coût réduit.",
      "Si l'Objet était inactif (non porté), ses parties nécessaires redeviennent actives pour l'opération.",
      "Combo naturel avec [Dégainer] et les Objets chers : l'Expert amortit les coûts d'équipement."
    ],
    cases: [
      {
        q: "L'Objet est déjà porté par une autre unité : Expert en armes peut-il le récupérer ?",
        a: "Oui : il choisit une carte Objet que vous contrôlez — la ré-équiper sur la nouvelle unité la déséquipe de l'ancienne."
      },
      {
        q: "La réduction peut-elle rendre l'équipement gratuit ?",
        a: "Oui, si la réduction couvre tout le coût — un coût ne descend jamais sous zéro."
      },
      {
        q: "Puis-je refuser ?",
        a: "Oui : « vous pouvez » — la compétence est optionnelle."
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
      "[Unique] n'est pas un effet en jeu : c'est une **restriction de construction de deck** — un seul exemplaire de cette carte au lieu des 3 habituels.",
      "En partie, la carte se comporte normalement : aucun effet spécial lié au mot-clé.",
      "La limite s'applique par **nom de carte** : plusieurs cartes Uniques différentes cohabitent sans problème."
    ],
    cases: [
      {
        q: "Puis-je avoir deux Uniques différents ?",
        a: "Oui : la limite s'applique par nom de carte, pas au mot-clé dans son ensemble."
      },
      {
        q: "Puis-je avoir deux exemplaires en jeu (l'un volé à l'adversaire) ?",
        a: "Oui : Unique ne contraint que la construction du deck, pas la table."
      }
    ],
    sections: ["825"],
    examples: [
      { id: "sfd-190-221", name: "Forgefire Cape", img: img("9bc49433a6ec5a8f4f1b44351094523d51b6bc11-744x1039.png") }
    ]
  }
]

export const topicBySlug = (slug) => TOPICS.find((t) => t.slug === slug)
