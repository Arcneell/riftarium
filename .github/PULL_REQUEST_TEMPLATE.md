## Résumé

<!-- Une ou deux phrases : ce que change cette PR. -->

## Pourquoi

<!-- Contexte, bug ou intention produit. -->

## Tests

- [ ] API : `docker compose run --rm api pytest -q` (depuis `riftarium/`)
- [ ] Web : `npm run check` (depuis `riftarium/apps/web`)
- [ ] Compose : `docker compose -f riftarium/compose.yaml config`

## Checklist

- [ ] Pas de secret, mot de passe ou jeton dans le diff
- [ ] Non-régression : accueil, cartothèque, API cartes
- [ ] Lint et formatage passent
