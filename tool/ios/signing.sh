#!/usr/bin/env bash
# Mac olmadan iOS dağıtım sertifikası hazırlar (yalnızca openssl gerekir).
#
#   tool/ios/signing.sh csr                 # özel anahtar + CSR üretir; CSR'ı Apple'a yükle
#   tool/ios/signing.sh p12 distribution.cer  # Apple'dan inen .cer'i anahtarla birleştirip .p12 yapar
#   tool/ios/signing.sh b64 DOSYA           # GitHub gizli değeri için tek satır base64 basar
#
# Dosyalar KEY_DIR'e yazılır (varsayılan ~/keys/ios). Bu klasör depoya ASLA girmez.
set -euo pipefail

KEY_DIR="${KEY_DIR:-$HOME/keys/ios}"
KEY="$KEY_DIR/ios_distribution.key"
CSR="$KEY_DIR/ios_distribution.csr"
P12="$KEY_DIR/ios_distribution.p12"

case "${1:-}" in
  csr)
    mkdir -p "$KEY_DIR"; chmod 700 "$KEY_DIR"
    if [ -e "$KEY" ]; then echo "$KEY zaten var; üzerine yazmıyorum." >&2; exit 1; fi
    EMAIL="${EMAIL:-$(git config user.email)}"
    openssl genrsa -out "$KEY" 2048
    chmod 600 "$KEY"
    openssl req -new -key "$KEY" -out "$CSR" -subj "/emailAddress=$EMAIL/CN=Chess Academy Distribution/C=TR"
    echo "CSR: $CSR"
    echo "developer.apple.com → Certificates → + → Apple Distribution → bu CSR'ı yükle, .cer'i indir."
    ;;
  p12)
    CER="${2:?Kullanım: $0 p12 distribution.cer}"
    [ -e "$KEY" ] || { echo "$KEY yok; önce '$0 csr' çalıştır." >&2; exit 1; }
    read -rsp "p12 parolası (GitHub'a IOS_DIST_CERT_PASSWORD olarak girilecek): " PASS; echo
    openssl x509 -inform DER -in "$CER" -out "$KEY_DIR/ios_distribution.pem"
    # macOS 'security import' eski PKCS#12 şifrelemesini bekler; OpenSSL 3 varsayılanı içe alınamayabilir.
    openssl pkcs12 -export -inkey "$KEY" -in "$KEY_DIR/ios_distribution.pem" -out "$P12" \
      -name "Chess Academy Distribution" -passout "pass:$PASS" \
      -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1
    chmod 600 "$P12"
    echo "P12: $P12"
    echo "Sonra: $0 b64 $P12  → IOS_DIST_CERT_P12_BASE64"
    ;;
  b64)
    base64 -w0 "${2:?Kullanım: $0 b64 DOSYA}"; echo
    ;;
  *)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
