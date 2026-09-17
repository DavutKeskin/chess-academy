import 'dart:math';

/// Oda kimliği: isim ya da yazı yerine üç emoji. Liste sabittir ve protokol sürümüyle
/// birlikte değişir; TXT kaydında yalnızca indeksler taşınır. Çocuklara uygun, eski
/// Android sürümlerinde de çizilen basit emojiler seçildi.
const List<String> roomEmoji = [
  '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯', '🦁', '🐮',
  '🐷', '🐸', '🐵', '🐧', '🐦', '🐴', '🐝', '🐢', '🐬', '🐳', '🐙', '🦋',
  '🌟', '🌈', '🍎', '🍓', '🍉', '⚽', '🎈', '🚀',
];

/// Rastgele üç farklı emoji indeksi.
List<int> randomRoomEmoji([Random? rng]) {
  final r = rng ?? Random();
  final picked = <int>[];
  while (picked.length < 3) {
    final i = r.nextInt(roomEmoji.length);
    if (!picked.contains(i)) picked.add(i);
  }
  return picked;
}

/// İndeks listesini görünen emoji dizgesine çevirir; geçersiz indeksler atlanır.
String roomEmojiText(List<int> indices) =>
    [for (final i in indices) if (i >= 0 && i < roomEmoji.length) roomEmoji[i]].join(' ');

/// TXT kaydı için "3,17,42" biçimi ve tersi.
String encodeRoomEmoji(List<int> indices) => indices.join(',');

List<int> decodeRoomEmoji(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  final result = <int>[];
  for (final part in raw.split(',')) {
    final i = int.tryParse(part.trim());
    if (i != null && i >= 0 && i < roomEmoji.length) result.add(i);
  }
  return result;
}
