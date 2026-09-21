# iOS: Mac olmadan derleme ve TestFlight

Derleme GitHub Actions'ın macOS makinelerinde yapılır (`.github/workflows/ios.yml`). Depo public olduğu için
bu makineler ücretsiz. Bu klasördeki betik yalnızca `openssl` ister, Linux'ta çalışır.

## İş akışı ne yapar?
- **Her push / PR:** Linux'ta `flutter analyze` + `flutter test`, macOS'ta imzasız `flutter build ios --release`.
  Stockfish dahil her şeyin iOS için derlendiğini gösterir. Gizli değer gerekmez.
- **Elle çalıştırma:** Actions → iOS → *Run workflow* → `testflight` işaretli. İmzalı IPA derlenir ve
  TestFlight'a yüklenir. Aynı sürümde ikinci yükleme için `build_number` ver (her yükleme daha büyük olmalı).

## Tek seferlik kurulum
Apple Developer Program üyeliği onaylandıktan sonra:

1. **Uygulama kimliği:** developer.apple.com → Identifiers → + → App IDs → App.
   Bundle ID `com.davutkeskin.chessacademy` (Explicit). In-App Purchase varsayılan olarak açık gelir.
2. **Sertifika:**
   ```
   tool/ios/signing.sh csr
   ```
   Certificates → + → **Apple Distribution** → `~/keys/ios/ios_distribution.csr` yükle → `.cer` indir.
   ```
   tool/ios/signing.sh p12 ~/Downloads/distribution.cer
   ```
3. **Profil:** Profiles → + → Distribution → **App Store Connect** → bu App ID → bu sertifika → indir
   (`.mobileprovision`). Sertifika yenilenince profil de yeniden oluşturulmalı.
4. **App Store Connect:** Apps → + → New App (iOS, aynı Bundle ID). Uygulama kaydı olmadan yükleme reddedilir.
5. **API anahtarı:** App Store Connect → Users and Access → Integrations → App Store Connect API →
   Team Keys → + (rol: App Manager). Issuer ID, Key ID ve bir kez inebilen `.p8` dosyası.
6. **GitHub → Settings → Secrets and variables → Actions → New repository secret:**

   | Gizli değer | İçerik |
   |---|---|
   | `IOS_DIST_CERT_P12_BASE64` | `tool/ios/signing.sh b64 ~/keys/ios/ios_distribution.p12` |
   | `IOS_DIST_CERT_PASSWORD` | p12 parolası |
   | `IOS_PROFILE_BASE64` | `tool/ios/signing.sh b64 ~/Downloads/<profil>.mobileprovision` |
   | `ASC_KEY_ID` | API Key ID |
   | `ASC_ISSUER_ID` | Issuer ID |
   | `ASC_KEY_P8` | `.p8` dosyasının tüm içeriği (BEGIN/END satırları dahil) |

   `~/keys/ios/` içindekileri (özel anahtar, p12, p8) Drive'a yedekle; depoya asla koyma.
   Takım kimliği profilden okunur, ayrıca girilmez.

## Satın alma
App Store Connect → uygulama → Monetization → In-App Purchases → **Non-Consumable**, Product ID `lessons_full`
(Android ile aynı; kod değişmez). Satın almanın çalışması için Business bölümünde ücretli uygulama sözleşmesi,
banka ve vergi bilgisi tamamlanmış olmalı. TestFlight'ta satın alma sandbox'tır, ücret alınmaz.

## Sık sorunlar
- `security import` "MAC verification failed": p12'yi `signing.sh p12` ile üret (eski şifreleme seçenekleri).
- "No profiles for ... were found": profil sertifikayla eşleşmiyor ya da süresi geçmiş; profili yeniden indir.
- Yükleme "bundle version must be higher": `build_number` girdisini artır.
