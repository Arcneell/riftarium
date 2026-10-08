# Échanges entre joueurs — conception (v1)

Date : 8 octobre 2026. Contrat d'API détaillé : `riftarium/docs/echanges.md`
(source de vérité des modèles, endpoints et e-mails ; ce document porte
l'intention, les décisions et les écrans).

## 1. Intention

Retour d'un joueur réunionnais : plutôt qu'une marketplace « à la Cardmarket »,
un système de **mise en relation** — « si tu cherches telle carte et que
quelqu'un l'a, ça vous met en contact » — pour échanger facilement **à La
Réunion**, avec l'idée d'en parler dans les boutiques du Sud.

Succès v1 : un joueur qui a activé les échanges voit en un écran qui, près de
chez lui, propose une carte de sa wishlist ; il manifeste son intérêt en deux
clics ; l'autre est prévenu par e-mail, accepte, et chacun voit le contact de
l'autre pour conclure hors du site.

Contraintes :
- projet fan gratuit : aucun prix, paiement ni commission (politique Riot sur
  l'exploitation commerciale de la propriété intellectuelle) ;
- livré avec la refonte « Forge noxienne », dans sa charte ;
- vie privée : opt-in, zone grossière, contact dévoilé seulement après accord.

## 2. Décisions

| Sujet | Choix | Écartés |
| --- | --- | --- |
| Mise en contact | Contact externe déclaré + demande sur le site, contact dévoilé à l'acceptation, notification e-mail | Contact affiché d'emblée ; messagerie interne (modération, spam, RGPD) |
| Ce que je cède | Liste « À échanger » explicite sur les lots de collection, avec quantité | Doublons automatiques ; suggestions de doublons |
| Ce que je cherche | Wishlist existante | Nouvelle liste |
| Proximité | Zone déclarée : Nord, Sud, Est, Ouest (Réunion seule) | Ville / code postal ; pas de géographie ; zones hors île |
| Contenu d'une demande | Une offre (un lot) + message optionnel | Proposition structurée X contre Y ; panier |
| Sens | « Ils cherchent ce que j'ai » en simple information | Demande inverse « je peux te céder » |
| Calcul des correspondances | Requêtes SQL à la volée (index `card_id`) | Table précalculée ; tâche périodique |
| Plateformes | API + web (branche refonte), mobile ensuite sur le même contrat | Tout en même temps ; web sur `main` dans l'ancienne charte |

## 3. Données

Résumé (détail et contraintes : contrat §Modèles) :
- `users` : `trade_enabled`, `trade_zone`, `trade_contact`, `notify_trades`.
- `trade_offers` : une offre par lot de collection (`collection_item_id`
  unique), `qty` bornée par le lot, recalée quand le lot diminue.
- `trade_requests` : demandeur, propriétaire, offre (SET NULL), carte / état /
  langue copiés, message, statut, dates.

Garde-fous : pas de demande à soi-même ; e-mail vérifié pour demander ; 10
demandes `pending` sortantes au plus ; une seule `pending` par (demandeur,
offre) ; comptes suspendus et non inscrits aux échanges invisibles.

## 4. API

Nouveau routeur `app/routers/trades.py` (préfixe `/api/trades`), logique de
correspondance dans `app/trades.py` (fonctions pures sur la session, testables
seules), réglages via `PATCH /api/auth/me`, recalage des offres appelé depuis
`routers/collection.py`, e-mails dans `app/mailer.py` (copies sur le modèle de
`_moderation_copy`, envoi via `BackgroundTasks`), limite `limit_trades` dans
`app/security.py` sur le modèle de `limit_play`. Endpoints, formes et codes
d'erreur : contrat.

## 5. Écrans web (charte Forge noxienne)

Composants `src/ui/` uniquement ; aucune règle de composant dans les vues
(`apps/web/README.md`).

**Navigation** — troisième enfant de la rubrique Collection dans
`src/shell/navigation.js` : Collection | Wishlist | **Échanges** (`/echanges`
ajouté à `prefixes`). Pas de nouvelle icône de rail ni d'onglet mobile (la barre
téléphone reste alignée sur Flutter). Pastille sur la rubrique et le
sous-onglet quand `incoming_pending > 0` (`/requests/summary`, rafraîchi à la
navigation).

**`/echanges` — `TradesView.vue`** (route protégée, comme `/collection`)
- *Non activé* : `RiftEmpty` qui explique le principe (donnant-donnant, La
  Réunion, contact dévoilé après accord) et formulaire sur place — zone
  (`RiftChoice`), contact (`RiftField`), « Activer les échanges ».
- *Activé* : `RiftSegments` (état dans `?onglet=`) :
  1. **Correspondances** — « Ils ont ce que je cherche » : grille de `CardTile`,
     sous chaque carte ses offres (avatar, pseudo, zone en `RiftChip static`,
     état, langue, quantité, mention « Échange possible » si `mutual`), bouton
     « Je suis intéressé » (ou « Demande envoyée » si `pending_request_id`).
     Le bouton ouvre `RiftModal` (`RiftSheet` au téléphone) : rappel de la
     carte, message optionnel (280 car.), envoyer. Puis « Ils cherchent ce que
     j'ai » en liste (pseudo, zone, cartes). Filtres : « Ma zone seulement »,
     recherche par nom.
  2. **Mes offres** — mes lots proposés, `RiftStepper` (0 retire), lien
     « Ajouter depuis ma collection ».
  3. **Demandes** — sous-segments Reçues | Envoyées ; ligne : carte, pseudo,
     zone, message, statut, actions selon le rôle (Accepter / Refuser,
     Annuler, Marquer comme fait). Demande acceptée : contact de l'autre dans
     un `RiftPanel accent` avec bouton « Copier ». `?id=` fait défiler jusqu'à
     la demande et la met en évidence (lien des e-mails).

**Collection** — feuille d'édition d'un lot : ligne « À échanger » avec
`RiftStepper` (0 → quantité du lot), si les échanges sont activés.

**Fiche carte** (`CardView`) — bloc « À l'échange » : « N joueurs la
proposent, dont M dans ta zone », offres et bouton « Je suis intéressé ».
Échanges non activés : invitation vers `/echanges`. Non connecté : rien.

**Profil** (`/profil`) — `RiftPanel` « Échanges » : interrupteur, zone,
contact, case « Me prévenir par e-mail ».

**Profil public** : inchangé en v1.

## 6. Erreurs et cas limites

- Offre supprimée ou ramenée à 0 : demandes `pending` → `cancelled` ; les
  `accepted` restent lisibles (carte copiée).
- Désactivation des échanges : offres conservées mais invisibles ; `pending`
  reçues et envoyées → `cancelled` ; `accepted` conservées avec contact.
- Compte suspendu : absent des correspondances ; ses offres refusent les
  nouvelles demandes (404).
- Transition interdite : 409 avec `detail` en français, affiché tel quel.
- Échec d'e-mail : journalisé, jamais propagé.
- Web : squelette, état vide et erreur par panneau ; hors ligne : bandeau
  existant ; erreurs d'action affichées près du bouton, sans perdre le message
  saisi.

## 7. Tests

**API** (`tests/test_trades.py`, pytest) : opt-in (visibilité, 403) ; 422
d'activation incomplète ; offres bornées et recalage au PATCH / suppression de
lot ; correspondances `wanted` / `offered` / par carte (croisement wishlist,
`mutual`, tri par zone, exclusions soi / suspendus / non inscrits) ; machine à
états et droits de chaque partie ; contact absent avant acceptation ; limite
des 10 `pending` et unicité ; e-mails selon `notify_trades`, adresse vérifiée
et fenêtre de 24 h (mailer simulé) ; désactivation qui annule les `pending` ;
export RGPD et cascade de suppression. Migration `0011` montée et descendue.

**Web** (Vitest) : `TradesView.spec.js` (non activé → activation, trois
segments, modale d'intérêt, contact visible après acceptation, `?id=`) ; specs
ciblées pour la ligne « À échanger » de la collection, le bloc de la fiche
carte, le panneau du profil et la pastille de navigation ;
`cssCoverage.spec.js` vert.

## 8. Livraison

- Branche `feat/refonte-echanges` depuis `refonte/forge`, PR vers
  `refonte/forge` (WORKFLOW.md §9, exception refonte).
- Commits : `Docs : contrat des échanges` · `API : échanges — modèles et
  migration 0011` · `API : échanges — offres, correspondances, demandes` ·
  `API : échanges — notifications e-mail` · `Web : échanges — page, collection,
  fiche carte, profil`.
- Vérifications : ruff + pytest (venv), `npm run check`.
- `WORKFLOW.md` §7 : renvoi vers `riftarium/docs/echanges.md`.
- Mobile : `feat/mobile-echanges` depuis `main` après le merge de la refonte.

## 9. Hors v1

Demandes dans les deux sens ; récapitulatif e-mail périodique ; zones hors
Réunion ; lieux d'échange / boutiques partenaires ; mise à jour automatique des
collections après « fait » ; prix ou mention de vente.
