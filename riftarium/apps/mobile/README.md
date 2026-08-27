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

## Tester sur un téléphone Android sans câble

Chaque exécution du workflow **Mobile** (PR ou push sur `main` touchant
`apps/mobile`, ou lancement manuel) dépose un APK de test en artefact :
GitHub → Actions → run « Mobile » → *Artifacts* → `riftarium-android-apk`.
Télécharger sur le téléphone, ouvrir le fichier, autoriser l'installation depuis
cette source. L'APK est signé avec la clé de debug : il s'installe hors Play Store
et vise l'API de production.

En local : `flutter build apk --release`, puis `adb install -r build/app/outputs/flutter-apk/app-release.apk`.

## iOS

Build et signature uniquement sur Mac (Xcode, compte développeur Apple) :
`flutter build ipa`. Le plugin de reconnaissance de texte (ML Kit) exige un
déploiement iOS ≥ 15.5 : régler `platform :ios, '15.5'` dans `ios/Podfile`
(généré au premier build sur Mac).
