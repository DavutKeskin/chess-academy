# Chess Academy (Satranç Akademi)

Çocuklar ve yeni başlayanlar için Türkçe satranç öğrenme uygulaması. Flutter ile yazıldı; tahta ve kurallar lichess'in `chessground` ve `dartchess` paketleri, rakip Stockfish.

- Dersler, tek ve iki hamlede mat bulmacaları, 5 seviyeli bilgisayar rakibi, ilerleme ve rozetler
- 10 tahta teması, 9 taş seti; aralarında uygulamaya özel "Hilal" seti (şahta ve filde haç yerine hilal)
- Gizlilik: hiçbir veri toplanmaz, her şey cihazda kalır (`PRIVACY_POLICY.md`)

Web sitesi ve gizlilik politikası: https://davutkeskin.github.io/chess-academy/ (kaynak `docs/`).

Geliştirme notları için `CLAUDE.md`.

## Lisans

Copyright (C) 2026 Davut Keskin

Bu program özgür yazılımdır: [GNU Genel Kamu Lisansı sürüm 3](LICENSE) ya da (isteğe bağlı olarak) sonraki bir
sürümün koşullarıyla dağıtabilir ve değiştirebilirsiniz. Hiçbir garanti verilmez. Bağımlılıklar `chessground`,
`dartchess` ve `stockfish` GPL-3.0 olduğu için uygulamanın tamamı bu lisansla dağıtılır.

- Bulmacalar lichess.org açık bulmaca veritabanından (CC0).
- "Hilal" taş seti, Colin M.L. Burnett'in cburnett setinden türetilmiştir (GPLv2+; ayrıntı `assets/pieces/hilal/README.md`).
- Ek koşul (GPLv3 madde 7(e)): "Satranç Akademi" / "Chess Academy" adı ve logosu üzerinde marka hakkı verilmez.
  Türev sürümlerin bu ad ve logoyla, özgün uygulamayla karıştırılacak biçimde dağıtılmaması beklenir.
