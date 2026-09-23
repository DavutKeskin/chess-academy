import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart' as nsd;

import 'protocol.dart';
import 'room_emoji.dart';

/// mDNS (nsd paketi) yalnızca bu platformlarda var; Linux'ta ve testte kapalı.
bool get lanDiscoverySupported =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

/// Ağda duyurulan bir oda. TXT kaydı: proto, emoji (indeksler), side (w/b/r).
class LanRoom {
  const LanRoom({
    required this.name,
    required this.emoji,
    required this.hostSide,
    required this.proto,
    required this.port,
    this.host,
    this.addresses = const [],
  });

  /// Hizmet adı (ASCII, "sa-1234"); kullanıcıya gösterilmez.
  final String name;
  final List<int> emoji;

  /// 'w' | 'b' | 'r' (ev sahibi rastgele seçti).
  final String hostSide;
  final int proto;
  final int port;
  final String? host;
  final List<InternetAddress> addresses;

  bool get isCompatible => proto == lanProtocolVersion;

  /// Bağlanılacak adres: önce IPv4, yoksa hizmetin ana makine adı.
  String? get connectAddress {
    for (final a in addresses) {
      if (a.type == InternetAddressType.IPv4) return a.address;
    }
    if (addresses.isNotEmpty) return addresses.first.address;
    return host;
  }

  static Map<String, String> txtFor({required List<int> emoji, required String hostSide}) => {
        'proto': '$lanProtocolVersion',
        'emoji': encodeRoomEmoji(emoji),
        'side': hostSide,
      };

  /// Rastgele, RFC 6335'e uygun kısa hizmet adı.
  static String randomName([Random? rng]) => 'sa-${(rng ?? Random()).nextInt(9000) + 1000}';

  /// Aynı oda mDNS'ten birden çok kez gelebilir (IPv4/IPv6 ayrı kayıt, yeniden duyuru);
  /// hizmet adına göre tekilleştirir, adresleri birleştirir.
  static List<LanRoom> dedupe(Iterable<LanRoom> rooms) {
    final byName = <String, LanRoom>{};
    for (final r in rooms) {
      final key = r.name.isNotEmpty ? r.name : '${r.host}:${r.port}:${encodeRoomEmoji(r.emoji)}';
      final prev = byName[key];
      byName[key] = prev == null
          ? r
          : LanRoom(
              name: prev.name,
              emoji: prev.emoji,
              hostSide: prev.hostSide,
              proto: prev.proto,
              port: prev.port,
              host: prev.host ?? r.host,
              addresses: [...prev.addresses, for (final a in r.addresses) if (!prev.addresses.contains(a)) a],
            );
    }
    return byName.values.toList();
  }

  /// TXT kaydından oda üretir; kayıt eksikse (başka bir uygulama) null.
  static LanRoom? fromService(nsd.Service s) {
    final txt = s.txt;
    final port = s.port;
    if (txt == null || port == null) return null;
    String? read(String key) {
      final v = txt[key];
      return v == null ? null : utf8.decode(v, allowMalformed: true);
    }

    final proto = int.tryParse(read('proto') ?? '');
    if (proto == null) return null;
    return LanRoom(
      name: s.name ?? '',
      emoji: decodeRoomEmoji(read('emoji')),
      hostSide: read('side') ?? 'r',
      proto: proto,
      port: port,
      host: s.host,
      addresses: s.addresses ?? const [],
    );
  }
}

/// Odayı ağda duyurur.
abstract class RoomAdvertiser {
  Future<void> start({required String name, required int port, required Map<String, String> txt});
  Future<void> stop();

  /// Platform destekliyorsa mDNS, değilse hiçbir şey yapmayan sürüm.
  factory RoomAdvertiser.platform() =>
      lanDiscoverySupported ? NsdRoomAdvertiser() : NoopRoomAdvertiser();
}

class NoopRoomAdvertiser implements RoomAdvertiser {
  @override
  Future<void> start({required String name, required int port, required Map<String, String> txt}) async {}
  @override
  Future<void> stop() async {}
}

class NsdRoomAdvertiser implements RoomAdvertiser {
  nsd.Registration? _registration;

  @override
  Future<void> start({required String name, required int port, required Map<String, String> txt}) async {
    _registration = await nsd.register(nsd.Service(
      name: name,
      type: lanServiceType,
      port: port,
      txt: {for (final e in txt.entries) e.key: Uint8List.fromList(utf8.encode(e.value))},
    ));
  }

  @override
  Future<void> stop() async {
    final r = _registration;
    _registration = null;
    if (r != null) {
      try {
        await nsd.unregister(r);
      } catch (_) {}
    }
  }
}

/// Ağdaki odaları listeler; liste değişince dinleyicilere haber verir.
abstract class RoomFinder extends ChangeNotifier {
  RoomFinder();

  List<LanRoom> get rooms;
  Future<void> start();
  Future<void> stop();

  factory RoomFinder.platform() => lanDiscoverySupported ? NsdRoomFinder() : NoopRoomFinder();
}

class NoopRoomFinder extends RoomFinder {
  @override
  List<LanRoom> get rooms => const [];
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
}

class NsdRoomFinder extends RoomFinder {
  nsd.Discovery? _discovery;
  List<LanRoom> _rooms = const [];

  @override
  List<LanRoom> get rooms => _rooms;

  @override
  Future<void> start() async {
    final d = await nsd.startDiscovery(lanServiceType, ipLookupType: nsd.IpLookupType.any);
    _discovery = d;
    d.addListener(_refresh);
    _refresh();
  }

  void _refresh() {
    final d = _discovery;
    if (d == null) return;
    _rooms = LanRoom.dedupe([for (final s in d.services) ?LanRoom.fromService(s)]);
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    final d = _discovery;
    _discovery = null;
    if (d != null) {
      d.removeListener(_refresh);
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
