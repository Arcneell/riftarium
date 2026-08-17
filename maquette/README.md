# Riftarium — maquette de présentation

Maquette statique du projet **Riftarium** (compagnon communautaire Riftbound), destinée à être
présentée à Riot Games pour la demande d'accès à l'API (politique développeur Riftbound).

## Ouvrir

Aucun build, aucune dépendance : ouvrir `index.html` dans un navigateur (double-clic suffit).
Connexion internet requise pour les polices et les visuels de cartes (CDN officiel Riot).

## Pages

| Page | Contenu |
| --- | --- |
| `index.html` | Présentation du projet, six modules, note à l'attention de Riot |
| `cartes.html` | Cartothèque : recherche, filtres domaine/type, bascule FR/EN |
| `carte.html` | Fiche carte : texte FR/EN, estimation Cardmarket (fictive) |
| `collection.html` | Scan mobile (mock animé) + inventaire et valeur estimée |
| `decks.html` | Deck builder avec validation des règles / mode libre + decks publics |
| `communaute.html` | Fil communautaire, likes, badges de modération automatique |

## Données

- **12 cartes d'exemple** (set Origins) : visuels réels servis depuis `cmsassets.rgpub.io`,
  le CDN officiel de Riot — rien n'est rehébergé. Codes collector et studios d'illustration crédités.
- **Traductions FR des noms** : traductions de démonstration (les noms officiels FR viendront de l'API Riot).
- **Prix Cardmarket, decks, membres, compteurs** : données fictives, signalées comme telles
  dans le bandeau de chaque page.

## Mentions légales

Riftarium est un projet fan-made à but non lucratif, non affilié à Riot Games, créé en vertu de la
politique « Jargon juridique » de Riot Games. Riot Games ne soutient ni ne sponsorise ce projet.
Visuels et textes de cartes © Riot Games, Inc. Cardmarket est une marque de Cardmarket GmbH.
Le pied de page de chaque page reprend ces mentions en intégralité.

Voir [`../REFONTE.md`](../REFONTE.md) pour le plan technique complet
(Vue 3 + FastAPI + PostgreSQL).
