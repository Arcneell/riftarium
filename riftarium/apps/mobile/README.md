# Riftarium — application mobile

Application iOS et Android en Flutter, cliente de l'API FastAPI (`apps/api`).
Le site Vue (`apps/web`) reste la version web ; les deux consomment la même API.

Le mode d'emploi complet (toolchain, commandes, architecture, feuille de route,
règles d'isolation vis-à-vis du reste du dépôt) est dans [`WORKFLOW.md`](../../../WORKFLOW.md)
à la racine du dépôt.

## Développer

```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter run                     # appareil ou émulateur branché (API prod par défaut)
```

L'API visée est fixée au build (`lib/core/config.dart`) :

```bash
# Production (défaut) : https://riftarium.re/api
flutter run
# Stack dev Docker (compose.dev) depuis l'émulateur Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8889/api
# Depuis un téléphone sur le même Wi-Fi que le PC
flutter run --dart-define=API_BASE_URL=http://<IP-LAN-du-PC>:8889/api
```

En debug, le HTTP en clair est autorisé (Android `usesCleartextTraffic`, iOS
`NSAllowsLocalNetworking`) ; en release, seule l'API HTTPS de production répond.

## Construire l'APK de test

```bash
scripts/apk.sh            # dist/riftarium-<version>-<sha>.apk (release, signé debug)
scripts/apk.sh --install  # + installation sur le téléphone branché (adb)
```

L'APK s'installe hors Play Store (autoriser la source) et vise l'API de
production. Pas de build en CI : trop long pour le quota GitHub Actions ; le
workflow « Mobile » ne fait que format, analyse et tests.

## iOS

Build et signature uniquement sur Mac (Xcode, compte développeur Apple) :
`flutter build ipa`. Le plugin de reconnaissance de texte (ML Kit) exige un
déploiement iOS ≥ 15.5 : régler `platform :ios, '15.5'` dans `ios/Podfile`
(généré au premier build sur Mac).
