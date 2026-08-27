#!/usr/bin/env bash
# Construit l'APK Android de test (release, signé avec la clé de debug : installable
# hors Play Store) et le range dans dist/ avec version et commit dans le nom.
#
#   scripts/apk.sh            construit dist/riftarium-<version>-<sha>.apk
#   scripts/apk.sh --install  puis l'installe sur l'appareil branché (adb)
#
# Pas de build en CI : trop long pour le quota GitHub Actions.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(sed -n 's/^version: *\([^+]*\).*/\1/p' pubspec.yaml)"
SHA="$(git rev-parse --short HEAD)"
OUT="dist/riftarium-${VERSION}-${SHA}.apk"

echo "construction de l'APK release…"
flutter build apk --release --suppress-analytics
mkdir -p dist
cp build/app/outputs/flutter-apk/app-release.apk "$OUT"
echo "APK : $OUT ($(du -h "$OUT" | cut -f1))"

if [[ "${1:-}" == "--install" ]]; then
  ADB="${ADB:-adb}"
  if ! command -v "$ADB" >/dev/null 2>&1; then
    ADB="${LOCALAPPDATA:-$HOME/AppData/Local}/Android/Sdk/platform-tools/adb.exe"
  fi
  echo "installation sur l'appareil…"
  "$ADB" install -r "$OUT"
fi
