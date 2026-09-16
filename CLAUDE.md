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
- `lib/features/puzzles/puzzles.dart` — Puzzle modeli + elle yazılmış 11 başlangıç bulmacası.
  `puzzle_repository.dart` açılışta `assets/puzzles/mate_in_1.json` (400) ve `mate_in_2.json` (300) yükler,
  kategoriler ve 20'lik bölümler üretir, günün bulmacasını tarihten seçer.
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

## Tasarım dili (2026-09-08)
- Renk kararları `lib/core/theme.dart` başındaki yorumda: lacivert (akademi/odak), altın (başarı/vurgu),
  krem yüzey, durum renkleri yalnızca geri bildirimde. Modül kimlik renkleri `AppColors.lessons/puzzles/play/progress`.
- Tahta ve taş seçimi `lib/core/settings_store.dart` (BoardTheme, PieceStyle); ekranlar `SettingsStore.instance.boardSettings` kullanır.
- "Hilal" taş seti uygulamaya özel: `assets/pieces/hilal/` (cburnett tabanlı, şahta haç ve filde artı yerine hilal; yıldızsız, eksene ortalı, hafif eğik).
  Kaynak SVG'ler aynı klasörde (`hilal_{w,b}K.svg`, `hilal_{w,b}B.svg`); değiştirince 1x/2x/3x webp'leri `magick` ile yeniden üret (bkz. klasördeki README).
- Ortak parçalar: `StatusBanner` (durum mesajı), `SectionHeader`.
- Geri bildirim: `lib/core/feedback.dart` (audioplayers + HapticFeedback), sesler `assets/sounds/*.wav`
  (Python ile sentezlendi). Ayarlar'dan kapatılır.
- İlk açılış: `features/onboarding` yaş/seviye sorar; `SettingsStore.level` dersleri açar ve rakip seviyesi önerir.
- Sürüm APK'ları artık yükleme anahtarıyla imzalı; telefonda debug imzalı eski kurulum varsa
  `adb uninstall` gerekir (INSTALL_FAILED_UPDATE_INCOMPATIBLE). Derleme zincirlerinde `grep -q '✓ Built'` ile başarıyı kontrol et.
- `android.injected.build.abi=...` özelliğini gradle.properties'e KOYMA: APK'yı testOnly işaretler (INSTALL_FAILED_TEST_ONLY).
  Tek ABI istersen `flutter build apk --release --split-per-abi` kullan; test kurulumunda gerekirse `adb install -t`.
