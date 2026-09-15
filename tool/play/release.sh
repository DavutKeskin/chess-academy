#!/usr/bin/env bash
# Sürüm yükleme: AAB derler, Play'e yükler (Play Developer API).
#   PLAY_PUBLISH_DIR=... tool/play/release.sh [kanal] [--draft]
#   kanal: internal | "Closed test" (kapalı test, varsayılan) | beta | production
# Sürüm numarasını önce pubspec.yaml'da artır (1.0.1+3 gibi); notlar store/release_notes.md.
# Yükleme betiği (publish.py + .venv) ve servis hesabı anahtarı bu depoda değildir.
# Ortam: PLAY_PUBLISH_DIR (zorunlu), FLUTTER (varsayılan PATH'teki flutter), AAB_DIR (varsayılan build/).
set -euo pipefail
cd "$(dirname "$0")/../.."
TRACK="${1:-Closed test}"; shift || true
F="${FLUTTER:-flutter}"
P="${PLAY_PUBLISH_DIR:?PLAY_PUBLISH_DIR ver: publish.py ve .venv içeren klasör}"
AAB_DIR="${AAB_DIR:-build}"
[[ -f "$P/publish.py" ]] || { echo "Yükleme betiği yok: $P/publish.py"; exit 1; }
PACKAGE=com.davutkeskin.chessacademy
VERSION=$(grep -E '^version:' pubspec.yaml | awk '{print $2}')
AAB="$AAB_DIR/ChessAcademy-${VERSION/+/-}.aab"
LOG=build/aab_build.log
echo "Sürüm $VERSION → $TRACK"
if [[ ! -f "$AAB" ]]; then
  mkdir -p build "$AAB_DIR"
  # Çıkış kodu ve "✓ Built" satırı ayrı kontrol edilir (grep -q'yu boruya bağlamak pipefail ile yanlış hata verebilir).
  if ! "$F" build appbundle --release --target-platform android-arm,android-arm64 >"$LOG" 2>&1 \
     || ! grep -q '✓ Built' "$LOG"; then
    echo "AAB derlenemedi, bkz. $LOG"; exit 1
  fi
  cp build/app/outputs/bundle/release/app-release.aab "$AAB"
fi
"$P/.venv/bin/python" "$P/publish.py" --package "$PACKAGE" upload --aab "$AAB" --track "$TRACK" --name "$VERSION" \
  --notes-file store/release_notes.md "$@"
