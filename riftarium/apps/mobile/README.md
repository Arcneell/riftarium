# Riftarium — application mobile

Application iOS et Android en Flutter, cliente de l'API FastAPI (`apps/api`).
Le site Vue (`apps/web`) reste la version web ; les deux consomment la même API.

Le mode d'emploi complet (toolchain, commandes, architecture, feuille de route,
règles d'isolation vis-à-vis du reste du dépôt) est dans [`WORKFLOW.md`](../../../WORKFLOW.md)
à la racine du dépôt.

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # appareil ou émulateur branché
```
