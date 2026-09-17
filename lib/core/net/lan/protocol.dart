import 'dart:convert';

import 'package:dartchess/dartchess.dart';

/// Yerel ağ oyunu protokolü. Her mesaj tek satır JSON; `t` alanı türü belirtir.
/// Sürüm uyuşmazlığında oyun kurulmaz (`error{code: 'proto'}`).
const int lanProtocolVersion = 1;

/// Uygulama kimliği: aynı ağdaki başka bir programla yanlışlıkla eşleşmeyi önler.
const String lanAppId = 'satranc';

/// mDNS hizmet türü.
const String lanServiceType = '_satranc._tcp';

sealed class LanMessage {
  const LanMessage();

  Map<String, Object?> toJson();

  String encode() => jsonEncode(toJson());

  /// Bozuk ya da tanınmayan satırda null döner (oturum bunu bağlantı hatası sayar).
  static LanMessage? decode(String line) {
    Object? raw;
    try {
      raw = jsonDecode(line);
    } catch (_) {
      return null;
    }
    if (raw is! Map<String, dynamic>) return null;
    try {
      switch (raw['t']) {
        case 'hello':
          return HelloMessage(proto: raw['proto'] as int, app: raw['app'] as String);
        case 'welcome':
          final side = raw['hostSide'];
          if (side != 'w' && side != 'b') return null;
          return WelcomeMessage(proto: raw['proto'] as int, hostSide: side == 'w' ? Side.white : Side.black);
        case 'move':
          return MoveMessage(ply: raw['ply'] as int, uci: raw['uci'] as String);
        case 'resign':
          return const ResignMessage();
        case 'ping':
          return const PingMessage();
        case 'pong':
          return const PongMessage();
        case 'error':
          return ErrorMessage(raw['code'] as String);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

/// Konuk → ev sahibi: bağlantının hemen ardından.
class HelloMessage extends LanMessage {
  const HelloMessage({this.proto = lanProtocolVersion, this.app = lanAppId});
  final int proto;
  final String app;

  bool get isCompatible => proto == lanProtocolVersion && app == lanAppId;

  @override
  Map<String, Object?> toJson() => {'t': 'hello', 'proto': proto, 'app': app};
}

/// Ev sahibi → konuk: oyun başlar; ev sahibinin rengi kesinleşmiştir.
class WelcomeMessage extends LanMessage {
  const WelcomeMessage({this.proto = lanProtocolVersion, required this.hostSide});
  final int proto;
  final Side hostSide;

  @override
  Map<String, Object?> toJson() =>
      {'t': 'welcome', 'proto': proto, 'hostSide': hostSide == Side.white ? 'w' : 'b'};
}

/// [ply] 0'dan başlar: oyundaki kaçıncı yarı hamle olduğu (sıra kontrolü için).
class MoveMessage extends LanMessage {
  const MoveMessage({required this.ply, required this.uci});
  final int ply;
  final String uci;

  @override
  Map<String, Object?> toJson() => {'t': 'move', 'ply': ply, 'uci': uci};
}

class ResignMessage extends LanMessage {
  const ResignMessage();
  @override
  Map<String, Object?> toJson() => const {'t': 'resign'};
}

class PingMessage extends LanMessage {
  const PingMessage();
  @override
  Map<String, Object?> toJson() => const {'t': 'ping'};
}

class PongMessage extends LanMessage {
  const PongMessage();
  @override
  Map<String, Object?> toJson() => const {'t': 'pong'};
}

/// Kodlar: 'proto' (sürüm/uygulama uyuşmazlığı), 'busy' (odada zaten rakip var),
/// 'badMove' (sırasız ya da kural dışı hamle), 'badMessage' (çözümlenemeyen satır).
class ErrorMessage extends LanMessage {
  const ErrorMessage(this.code);
  final String code;

  static const proto = 'proto';
  static const busy = 'busy';
  static const badMove = 'badMove';
  static const badMessage = 'badMessage';

  @override
  Map<String, Object?> toJson() => {'t': 'error', 'code': code};
}
