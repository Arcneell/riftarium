# Échanges entre joueurs — contrat d'API `/api/trades` (v1)

Source de vérité pour l'API (FastAPI), le site (Vue) et l'application mobile
(Flutter). Toute évolution passe d'abord par ce fichier. Conception et
décisions : `docs/superpowers/specs/2026-10-08-echanges-design.md` (racine du
dépôt).

## Principes

- **Mise en relation, pas de marketplace.** Riftarium montre qui a ce que je
  cherche ; l'échange (ou la vente) se règle entre joueurs, hors du site. Aucun
  prix, aucun paiement, aucune commission, pas le mot « vente » dans l'interface.
- **Opt-in** : sans `trade_enabled`, un compte n'apparaît dans aucune
  correspondance, ne voit pas celles des autres et ne peut ni envoyer ni recevoir
  de demande. Activer exige une zone et un contact.
- **Donnant-donnant** : les offres ne sont visibles qu'aux comptes connectés
  ayant activé les échanges. Aucune page publique, aucune offre sur le profil
  public.
- **« Je cherche » = la wishlist existante** ; **« À échanger » = une liste
  explicite** rattachée aux lots de la collection.
- **Le contact externe** (texte libre, ex. « Discord : bloblo974 ») n'est
  dévoilé qu'aux deux parties d'une demande acceptée. Jamais dans un e-mail.
- **Zones** : La Réunion uniquement en v1 — `nord`, `sud`, `est`, `ouest`.
- Une demande porte sur **une offre** (un lot d'une carte), avec un message
  optionnel. La suite se négocie via le contact externe.

## Modèles (SQLAlchemy, migration Alembic `0011_echanges`)

```
users           + trade_enabled (bool, défaut false)
                + trade_zone ('nord'|'sud'|'est'|'ouest', nullable)
                + trade_contact (varchar 80, nullable)
                + notify_trades (bool, défaut true)
trade_offers    id, user_id → users (cascade), collection_item_id → collection_items
                (cascade, unique), qty (int ≥ 1, ≤ qty du lot), created_at
trade_requests  id, requester_id → users (cascade), owner_id → users (cascade),
                trade_offer_id → trade_offers (SET NULL), card_id → cards,
                condition, lang (copiés de l'offre à la création),
                message (varchar 280, défaut ""), status
                ('pending'|'accepted'|'declined'|'cancelled'|'done'),
                created_at, responded_at (nullable), done_at (nullable)
                check requester_id <> owner_id
                index unique partiel : (requester_id, trade_offer_id) where status = 'pending'
```

Recalage des offres : quand la quantité d'un lot baisse (`PATCH
/api/collection/entries/{id}`, `PUT /api/collection/{card_id}`, import bulk),
l'offre est ramenée à `min(offre, lot)` ; à 0 (ou lot supprimé), l'offre est
supprimée et ses demandes `pending` passent en `cancelled`.

## Machine à états d'une demande

```
pending ──accept (owner)──▶ accepted ──done (l'un ou l'autre)──▶ done
   │ ──decline (owner)───▶ declined
   │ ──cancel (requester)─▶ cancelled
   └ (offre supprimée, échanges désactivés par l'une des parties) ─▶ cancelled
```

Toute autre transition : 409. Les demandes `accepted` survivent à la
suppression de l'offre et à la désactivation des échanges (contact toujours
visible jusqu'à `done`).

## Endpoints

Tous exigent un compte connecté. Limite d'écriture `limit_trades` (30 / min / IP).
Les erreurs portent un `detail` en français.

### Réglages (existant étendu)

| Méthode | Chemin | Effet |
| --- | --- | --- |
| PATCH | `/api/auth/me` | **ajoute** `trade_enabled`, `trade_zone`, `trade_contact`, `notify_trades`. 422 si `trade_enabled=true` alors que zone ou contact (après `strip`) manque. Désactiver annule les demandes `pending` (reçues et envoyées). `user_out` renvoie les quatre champs. |

### Ma liste « À échanger »

| Méthode | Chemin | Effet |
| --- | --- | --- |
| GET | `/api/trades/offers` | mes offres : `[{id, entry_id, card (card_out), condition, lang, qty, entry_qty, created_at}]` |
| PUT | `/api/trades/offers/{entry_id}` | `{qty}` : crée ou met à jour l'offre sur mon lot ; `qty=0` la supprime ; 404 si le lot n'est pas à moi ; 422 si `qty > entry_qty`. Possible même échanges désactivés (préparation). |
| DELETE | `/api/trades/offers/{entry_id}` | retire l'offre (204, idempotent) |

### Correspondances (403 si mes échanges ne sont pas activés)

Exclues partout : mes propres offres, les comptes suspendus, les comptes sans
`trade_enabled`.

| Méthode | Chemin | Effet |
| --- | --- | --- |
| GET | `/api/trades/matches/wanted?zone&q&page&size` | « Ils ont ce que je cherche » : offres des autres sur les cartes de **ma wishlist**, groupées par carte. `{items: [{card (card_out), wanted_qty, offers: [OfferOut]}], total, page, size}`. `size` ≤ 48. |
| GET | `/api/trades/matches/offered?zone&page&size` | « Ils cherchent ce que j'ai » : comptes dont la wishlist croise **mes offres**. `{items: [{user {handle, avatar_url, zone}, cards: [card_out]}], total, page, size}`. Lecture seule en v1. |
| GET | `/api/trades/cards/{card_id}/offers?zone` | offres des autres sur une carte (fiche carte) : `{offers: [OfferOut], total, in_my_zone}` |

`OfferOut = {offer_id, owner {handle, avatar_url, zone}, condition, lang, qty,
mutual, pending_request_id}` — `mutual` vrai si ce joueur a dans sa wishlist au
moins une carte de mes offres ; `pending_request_id` = ma demande en cours sur
cette offre (ou `null`).

Tri des offres : ma zone d'abord, puis `mutual`, puis offre la plus récente.
Tri des cartes (`wanted`) : nombre d'offres dans ma zone, puis nom. `zone`
filtre sur une zone précise.

### Demandes

| Méthode | Chemin | Effet |
| --- | --- | --- |
| POST | `/api/trades/requests` | `{offer_id, message?}` → 201 `RequestOut`. 403 si mon e-mail n'est pas vérifié ou si je n'ai pas activé les échanges ; 404 si offre inconnue, ou d'un compte suspendu ou désinscrit ; 422 si le message est refusé par la modération (même filtre que la bio) ; 409 si c'est ma propre offre ou si une demande `pending` existe déjà ; 429 au-delà de 10 demandes `pending` sortantes. |
| GET | `/api/trades/requests?box=in\|out&status&page&size` | mes demandes reçues (`in`) ou envoyées (`out`), les plus récentes d'abord |
| GET | `/api/trades/requests/{id}` | une demande (404 si je n'en suis pas partie) |
| POST | `/api/trades/requests/{id}/accept` | owner, depuis `pending` |
| POST | `/api/trades/requests/{id}/decline` | owner, depuis `pending` |
| POST | `/api/trades/requests/{id}/cancel` | requester, depuis `pending` |
| POST | `/api/trades/requests/{id}/done` | l'une ou l'autre partie, depuis `accepted` |
| GET | `/api/trades/requests/summary` | `{incoming_pending}` (pastille de navigation) |

`RequestOut = {id, box ('in'|'out'), status, card (card_out), condition, lang,
message, other {handle, avatar_url, zone}, contact, created_at, responded_at,
done_at}` — `contact` = `trade_contact` de l'autre partie, **présent seulement
si `status` ∈ {accepted, done}**, `null` sinon.

## Notifications e-mail (`app/mailer.py`)

Envoyées en tâche de fond, jamais bloquantes (un échec est journalisé, la
demande reste créée). Seulement si le destinataire a `notify_trades` et une
adresse vérifiée. Pied de page de désinscription `NOTIFY_OPT_OUT` (réglage du
profil).

1. **Nouvelle demande** → owner : « {handle} est intéressé par votre carte
   {nom} », message cité, bouton « Voir la demande ». Au plus **un e-mail par
   couple (demandeur → owner) toutes les 24 h** ; les suivantes restent visibles
   sur le site.
2. **Demande acceptée** → requester : « {handle} a accepté votre demande pour
   {nom} », bouton « Voir son contact ». Le contact n'est pas dans l'e-mail.

Pas d'e-mail pour un refus, une annulation ou « fait ».

Lien : `{base_url}/echanges?onglet=demandes&id={request_id}`.

## RGPD

- Suppression de compte : cascade sur offres et demandes (les deux côtés).
- Export (`/api/auth/export`) : réglages d'échange, offres, demandes envoyées et
  reçues (sans le contact de l'autre partie).

## Écrans

**Web** : sous-onglet « Échanges » de la rubrique Collection (`/echanges`),
segments Correspondances / Mes offres / Demandes ; ligne « À échanger » dans la
feuille d'édition d'un lot ; bloc « À l'échange » sur la fiche carte ; panneau
« Échanges » dans `/profil`. Détail : spec de conception.

**Mobile** : à venir (`feat/mobile-echanges`), même contrat.

## Hors v1

Demandes dans les deux sens (« je peux te céder X »), récapitulatif e-mail
périodique des nouvelles correspondances, zones hors Réunion, lieux d'échange
(boutiques), mise à jour automatique des collections après « fait », prix.
