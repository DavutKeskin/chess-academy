# Chess Academy (Satranç Akademi)

Çocuklar ve yeni başlayanlar için Türkçe satranç öğrenme uygulaması (Flutter).

## Komutlar
Flutter PATH'te olmayabilir (makineye özel yol `CLAUDE.local.md`'de):
```
F=flutter
$F pub get
$F analyze
$F test            # bulmaca/ders içeriklerini doğrular, içerik değişince mutlaka çalıştır
$F build apk --debug
```
Android için JDK 17 gerekir (`flutter config --jdk-dir`).

## Yapı
- `lib/core/engine/engine_service.dart` — tek paylaşımlı Stockfish süreci (sıralı istek kuyruğu, 90 sn boşta kapanır).
  `lib/core/bot/bot.dart` — rakip: telefonda EngineService (Skill Level), masaüstünde SimpleBot (minimax).
- `lib/core/analysis/game_analysis.dart` — oyun analizi: oyuncu hamlesi için en iyi hamle/skor karşılaştırması,
  nitelik eşikleri (50/100/300 cp), kaçırılan mat/taş tespiti, lichess doğruluk formülü; sonuç GameRecord'a kaydedilir.
  Arayüz: `features/play/replay_screen.dart` (ok işaretleri, değerlendirme çubuğu, en iyi devam simülasyonu, önemli anlar).
- `lib/core/progress_store.dart` — shared_preferences ile ilerleme, seri, rozetler.
- `lib/features/lessons/lessons.dart` — 20 ders (FEN + görev), 4 grup (temel, kurallar, taktik, mat). Yeni ders buraya eklenir;
  görev mat/şah iddiası taşıyorsa `mates: true` / `givesCheck: true` ver, test doğrular.
  Açıklama adımına ok: `arrows: ['b1b3']`; at görevlerinde oklar kendiliğinden L çizilir.
- `lib/features/puzzles/puzzles.dart` — Puzzle modeli + elle yazılmış 11 başlangıç bulmacası.
  `puzzle_repository.dart` açılışta `assets/puzzles/mate_in_1.json` (400) ve `mate_in_2.json` (300) yükler,
  kategoriler ve 20'lik bölümler üretir. Seviyeye göre (`SettingsStore.level`) puan dilimleri `_bands`:
  günün bulmacası seviye havuzundan tarihe göre, listede "Seviyene uygun bulmaca" sıradaki çözülmemişi açar.
- Bulmaca verisi Lichess CC0 veritabanından: `tool/lichess/filter_puzzles.py` (süzme: popülerlik ≥ 90,
  ≥ 2000 oynanma, puan aralığı) → `dart run tool/lichess/convert.dart` (rakip hamlesini uygular, dartchess ile
  doğrular, JSON yazar). Ham .zst dosyası git dışında; `curl -sL -o tool/lichess/lichess_db_puzzle.csv.zst https://database.lichess.org/lichess_db_puzzle.csv.zst`.
- Bulmaca kuralı: ara hamleler çözümle birebir, SON hamlede herhangi bir mat kabul. Testler tüm 711 bulmacayı doğrular.
- Tahta: `chessground`, kurallar: `dartchess` (lichess paketleri). Chess logic'i widget'a koyma.

## Ürün notları
- Gelir: `lib/core/purchase_store.dart`, Play ürün kimliği `lessons_full` (tek seferlik; fiyat Play Console'da tanımlanır).
  `freeLessonCount = 8` (lessons.dart); ücretli dersler `isPremiumLesson(i)`. Satın alma ekranı `features/paywall`.
  Debug derlemede satın alma ekranında test kilidi var; sürümde yok. Bulmacalar ücretsiz.
- Bulmaca sayısını artırmak için Lichess açık bulmaca veritabanı (CC0) kullanılabilir.

## Derleme notları (2026-09-08)
- `stockfish` paketi eski Gradle betiği kullandığı için AGP 9 ile derlenmez; proje AGP 8.13 + Gradle 8.14.3'e sabitlendi
  (`android/settings.gradle.kts`, `gradle-wrapper.properties`). Flutter'ın "yükselt" uyarısını görmezden gel.
- `android/gradle.properties` içindeki düşük bellek (`-Xmx2G`) ve `workers.max=1` bilinçli; yükseltirsen az RAM'li makinede clang OOM ile çöker.
- Stockfish gerçek telefonda (arm64) ~2 sn'de hazır; emülatörde 30 sn zaman aşımına düşüp SimpleBot'a geçer,
  bu emülatör yavaşlığından kaynaklanır, hata değil.
- Marka görselleri `python3 tool/branding/make_branding.py` ile üretilir (ImageMagick; kaynak SVG `tool/branding/king_cap.svg`:
  kepli, hilal alemli şah). Çıktılar `assets/branding/` ve `store/`. Sonra
  `flutter pub run flutter_launcher_icons` ve `flutter pub run flutter_native_splash:create` çalıştır.
- `PRIVACY_POLICY.md` mağaza için gizlilik metni; reklam/satın alma eklenince güncelle. Web sitesi `docs/` (GitHub Pages:
  index.html, privacy_policy.html → https://davutkeskin.github.io/chess-academy/privacy_policy.html; bu adres Play'de kayıtlı, bozma).
- Lisans GPL-3.0-or-later (`LICENSE`); sebebi GPL bağımlılıklar (chessground, dartchess, stockfish). Bu depo public;
  mağazaya çıkan her sürümün kaynağı burada olmalı, kaynak adresi `settings_screen.dart` `sourceCodeUrl`. Ayarlar → Hakkında → `showLicensePage`.
  Yeni bağımlılık eklerken lisansına bak (GPL-3.0 ile uyumlu olmalı). Gizli dosyaları (key.properties, *.jks, servis hesabı) asla commit etme.
- Bu depo PUBLIC: fiyat stratejisi, Play Console detayları, servis hesabı/proje kimliği, makine ve cihaz bilgisi,
  kişisel veri, ekran görüntüsü ham halleri buraya yazılmaz. Bunlar git dışı `CLAUDE.local.md` ve `private/` içinde.
- Play'e sürüm yükleme: `tool/play/release.sh` (Play Developer API; yükleme betiği depo dışında, `PLAY_PUBLISH_DIR` zorunlu, `FLUTTER`/`AAB_DIR` isteğe bağlı). Yükleme testçilere gider, kullanıcı onayıyla çalıştır.
- Mağaza paketi: `flutter build appbundle --release --target-platform android-arm,android-arm64` (x86_64 hariç; app build.gradle.kts
  `packaging.jniLibs.excludes` ile dışlanır, `abiFilters` işe yaramaz). İmza `android/key.properties` + git dışı yükleme anahtarı.

## Yerelleştirme (2026-09-10)
- 4 dil: tr (şablon), en, de, es. ARB dosyaları `lib/l10n/app_*.arb`; `flutter gen-l10n` ile `app_localizations*.dart` üretilir (git dışı).
- Arayüzde `context.t.anahtar`; içerik (dersler, başlangıç bulmacaları) `buildLessons(t)` ve `starterTitle/Hint(t, id)` ile üretilir.
- Yeni metin eklerken önce `app_tr.arb`'a, sonra diğer üç dile ekle; test her dilde 20 dersin üretildiğini doğrular.
- Dil seçimi `SettingsStore.language` (null = sistem). Cihazdaki uygulama adı `res/values*/strings.xml`.
- Mağaza metinleri: `store/listing_{tr,en,de,es}.md`.
- Oyun kaydı `lib/core/game_store.dart` (UCI + SAN, son 20 oyun); tekrar oynatma `features/play/replay_screen.dart`.
  Süreli oyunlar `lib/core/game_clock.dart` (TimeControl önayarları + GameClock; saat ilk hamlede başlar,
  arka planda durur, bayrak düşünce mat edecek taş yoksa berabere). GameRecord `tc`/`endedBy` alanları.

## Arkadaşla oyna, aynı Wi‑Fi (2026-09-17)
- Sunucusuz yerel ağ oyunu (MVP): ev sahibi oda kurar, konuk aynı Wi‑Fi'da bulup katılır. Süresiz, yalnızca bırakma;
  beraberlik teklifi, rövanş, yeniden bağlanma yok; kopuş oyunu bitirir (`endedBy: 'disconnect'`, sonuç berabere).
- Kod: `lib/core/net/lan/` — `transport.dart` (Transport: SocketTransport + testler için FakeTransport.pair),
  `protocol.dart` (satır satır JSON, `lanProtocolVersion = 1`, hizmet türü `_satranc._tcp`), `lan_session.dart`
  (el sıkışma hello/welcome, hamle doğrulama dartchess + yarı hamle sırası, resign, ping 3 sn / zaman aşımı 10 sn),
  `lan_host.dart` (ServerSocket, tek konuk; LanGuest.connect), `lan_discovery.dart` (nsd ile mDNS; TXT: proto, emoji, side),
  `room_emoji.dart` (oda kimliği: 3 emoji, isim/yazı yok), `remote_opponent.dart`.
- `lib/core/opponent.dart`: `Opponent` soyutlaması; `BotOpponent` (bilgisayar) ve `RemoteOpponent` aynı `PlayScreen`'i
  kullanır (`PlayScreen.remote`). Uzak oyunda `level: 0`, `GameRecord.isVsFriend`; ProgressStore'a sayılmaz, kayıt/analiz var.
- Arayüz: `features/play/lan_lobby_screen.dart` (lobi, oda kur: renk + emoji + bekleme, odaya katıl: emoji kartları).
  Debug derlemede oda ekranı IP:port gösterir ve katılma ekranında elle IP:port alanı vardır (mDNS'siz test).
- Protokolü değiştirirken `lanProtocolVersion` artır; eski sürüm `error{proto}` ile reddedilir. Emoji listesi de sürüme bağlıdır.
- Testler: `test/lan_protocol_test.dart`, `test/lan_session_test.dart` (FakeTransport, kısa zaman aşımları),
  `test/play_remote_test.dart` (sahte uzak rakiple oyun ekranı). Gerçek cihaz testi: PC'de `avahi-browse -r _satranc._tcp`
  ile duyuruyu gör; `avahi-publish -s sa-test _satranc._tcp PORT proto=1 emoji=1,2,3 side=w` ile sahte oda yayınla.
- Android izinleri: INTERNET, CHANGE_WIFI_MULTICAST_STATE (manifest). Gizlilik metni v1.2'de anlatıldı; veri toplanmıyor.
- nsd paketi (MIT) Linux'u desteklemez: masaüstünde `lanDiscoverySupported` false, ekran uyarı gösterir; testler etkilenmez.

## iOS (2026-09-19)
- Mac yok: derleme GitHub Actions macOS'ta (`.github/workflows/ios.yml`). Her push/PR: test (Linux) + imzasız
  `flutter build ios --release`. Elle çalıştırma `testflight` işaretliyse imzalı IPA → TestFlight (`build_number` girdisi).
  Kurulum ve gizli değer adları `tool/ios/README.md`; sertifika Linux'ta `tool/ios/signing.sh` (anahtarlar `~/keys/ios`, depoya girmez).
- Takım kimliği ve imza ayarları depoda yok; CI profilden okur, Runner Release'i yalnızca CI'da elle imzaya çevirir.
- Yalnızca iPhone (`TARGETED_DEVICE_FAMILY = 1`). iPad açılırsa sonradan kapatılamaz ve iPad ekran görüntüsü gerekir.
- Ana ekran adı ve yerel ağ izni metni `ios/Runner/{en,tr,de,es}.lproj/InfoPlist.strings`. Dil eklerken oraya,
  Info.plist `CFBundleLocalizations`'a ve pbxproj `knownRegions` + InfoPlist.strings grubuna ekle. Gizlilik manifesti `ios/Runner/PrivacyInfo.xcprivacy`.
- App Store'da Google Play'den söz edilemez: mağaza metinlerinin `*Ios` eşleri var (`storeNoteIos` vb., paywall `_isIOS`). Yeni mağaza metni eklerken iki varyant yaz.
- App Store'da Kids kategorisi seçme: Ayarlar'daki dış bağlantılar (kaynak kod, gizlilik) için ebeveyn kapısı gerekir.
- Stockfish pod'unun nnue indirme adımı Xcode sandbox'ında çalışmaz ("Could not find incbin file"); iOS derlemesinden önce `tool/ios/fetch_nnue.sh` (CI yapıyor, önbellekli, sha256 doğrulamalı). Gizlilik metni v1.3 App Store'u anlatır.

## Tasarım dili (2026-09-08)
- Renk kararları `lib/core/theme.dart` başındaki yorumda: lacivert (akademi/odak), altın (başarı/vurgu),
  krem yüzey, durum renkleri yalnızca geri bildirimde. Modül kimlik renkleri `AppColors.lessons/puzzles/play/progress`.
- Koyu tema (2026-09-17): `AppPalette.light/dark` (theme.dart); `AppColors.x` getter'ları etkin paletten okur, bu yüzden
  `const` içinde kullanılamaz. Tema `SettingsStore.themeMode` (sistem/açık/koyu); main.dart `_PaletteScope` değişince tüm ağacı
  yeniden çizer. Beyaz yazılı koyu kart zemini `AppColors.hero` / `puzzlesStrong`; yeni renk eklerken iki palete de ekle.
- Tahta ve taş seçimi `lib/core/settings_store.dart` (BoardTheme, PieceStyle); ekranlar `SettingsStore.instance.boardSettings` kullanır.
- "Hilal" taş seti uygulamaya özel: `assets/pieces/hilal/` (cburnett tabanlı, şahta haç ve filde artı yerine hilal; yıldızsız, eksene ortalı, hafif eğik).
  Kaynak SVG'ler aynı klasörde (`hilal_{w,b}K.svg`, `hilal_{w,b}B.svg`); değiştirince 1x/2x/3x webp'leri `magick` ile yeniden üret (bkz. klasördeki README).
- Ortak parçalar: `StatusBanner` (durum mesajı), `SectionHeader`.
- Geri bildirim: `lib/core/feedback.dart` (audioplayers + HapticFeedback), sesler `assets/sounds/*.wav`
  (Python ile sentezlendi). Ayarlar'dan kapatılır.
  Sesler arayüz sesi olarak çalar (Android USAGE_ASSISTANCE_SONIFICATION, ses odağı yok; iOS ambient):
  telefon sessiz/titreşimdeyken susar, çalan müziği durdurmaz. Medya kullanımına geri çevirme.
- İlk açılış: `features/onboarding` yaş/seviye sorar; `SettingsStore.level` dersleri açar ve rakip seviyesi önerir.
- Sürüm APK'ları artık yükleme anahtarıyla imzalı; telefonda debug imzalı eski kurulum varsa
  `adb uninstall` gerekir (INSTALL_FAILED_UPDATE_INCOMPATIBLE). Derleme zincirlerinde `grep -q '✓ Built'` ile başarıyı kontrol et.
- `android.injected.build.abi=...` özelliğini gradle.properties'e KOYMA: APK'yı testOnly işaretler (INSTALL_FAILED_TEST_ONLY).
  Tek ABI istersen `flutter build apk --release --split-per-abi` kullan; test kurulumunda gerekirse `adb install -t`.
