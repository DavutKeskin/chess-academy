#!/usr/bin/env bash
# Stockfish'in sinir ağı dosyalarını iOS derlemesinden önce paketin kaynak klasörüne koyar.
# stockfish paketinin podspec'i bunları derleme sırasında curl ile indirmeye çalışır, ama Xcode'un
# betik korumalı alanı Pods kaynağına yazmayı engeller ve derleme "Could not find incbin file" ile düşer.
# .incbin dosyayı -I yollarında değil derleyicinin çalışma klasöründe (ios/Pods) arar; bu yüzden dosyalar
# oraya da kopyalanır. Önce `flutter build ios --config-only` ile Pods oluşturulmalı (paket hatası #57).
# Dosya adı sha256 özetinin ilk 12 hanesidir; indirilen dosya buna göre doğrulanır.
# `flutter pub get` sonrasında çalıştır. Önbellek: NNUE_CACHE (varsayılan ~/.cache/stockfish-nnue).
set -euo pipefail
cd "$(dirname "$0")/../.."

PKG=$(python3 - <<'EOF'
import json, urllib.parse
cfg = json.load(open('.dart_tool/package_config.json'))
p = next(p for p in cfg['packages'] if p['name'] == 'stockfish')
print(urllib.parse.urlparse(p['rootUri']).path)
EOF
)
SRC="$PKG/ios/Stockfish/src"
CACHE="${NNUE_CACHE:-$HOME/.cache/stockfish-nnue}"
mkdir -p "$CACHE"

for name in $(sed -nE 's/^#define EvalFileDefaultName(Big|Small) "(.*)"$/\2/p' "$SRC/evaluate.h"); do
  if [ ! -e "$CACHE/$name" ]; then
    echo "İndiriliyor: $name"
    curl -fsSL --retry 3 -o "$CACHE/$name.part" "https://tests.stockfishchess.org/api/nn/$name"
    mv "$CACHE/$name.part" "$CACHE/$name"
  fi
  want=${name#nn-}; want=${want%.nnue}
  got=$( (sha256sum "$CACHE/$name" 2>/dev/null || shasum -a 256 "$CACHE/$name") | cut -c1-12)
  if [ "$got" != "$want" ]; then
    echo "$name özeti tutmuyor ($got); siliniyor." >&2
    rm -f "$CACHE/$name"; exit 1
  fi
  for dst in "$SRC" ios/Pods; do
    if [ -d "$dst" ]; then cp "$CACHE/$name" "$dst/$name"; echo "Hazır: $dst/$name"; fi
  done
done
