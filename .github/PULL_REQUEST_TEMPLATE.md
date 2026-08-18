## Résumé

<!-- Une ou deux phrases : ce que change cette PR. -->

## Pourquoi

<!-- Contexte, bug ou intention produit. -->

## Tests

- [ ] API : `pytest -q` (depuis `riftarium/apps/api`)
- [ ] Web : `npm run check` (depuis `riftarium/apps/web`)
- [ ] Compose : `python riftarium/scripts/check_compose_security.py` (secrets CI dans l'environnement)

## Checklist

- [ ] Pas de secret, mot de passe ou jeton dans le diff (`.env` exclu)
- [ ] `JWT_SECRET` / `DB_PASSWORD` / `ADMIN_TOKEN` / `REDIS_PASSWORD` documentés si le déploiement change
- [ ] Non-régression : accueil, cartothèque, API cartes
- [ ] Lint et formatage passent
