# Riftarium — consignes pour les agents

Avant toute tâche, lire et appliquer @WORKFLOW.md (organisation du dépôt,
règle web / API / mobile, toolchain, commandes de vérification, feuille de
route de l'application mobile Flutter).

Rappels courts :
- Trois applications dans `riftarium/apps/` : `api` (FastAPI), `web` (Vue 3),
  `mobile` (Flutter). Ne jamais modifier `web` ou `api` pour un besoin mobile
  sans que ce soit un changement de contrat d'API décrit dans WORKFLOW.md.
- Le scanner web, le service worker et le manifest PWA restent en place tant
  que l'application mobile n'est pas publiée. Ne pas les retirer.
- Langue du projet : français (commentaires, interface, commits, documentation).
- Avant de pousser : lancer les vérifications de chaque application touchée
  (section « Vérifier avant de pousser » de WORKFLOW.md).
