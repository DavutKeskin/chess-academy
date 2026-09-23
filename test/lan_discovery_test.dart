import 'dart:io';

import 'package:chess_academy/core/net/lan/lan_discovery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LanRoom room(String name, {List<InternetAddress> addresses = const [], String? host}) => LanRoom(
        name: name,
        emoji: const [1, 2, 3],
        hostSide: 'w',
        proto: 1,
        port: 5000,
        host: host,
        addresses: addresses,
      );

  test('aynı hizmet adıyla iki kayıt tek oda olur, adresler birleşir', () {
    final v6 = InternetAddress('fe80::1');
    final v4 = InternetAddress('192.168.1.5');
    final rooms = LanRoom.dedupe([room('sa-1234', addresses: [v6]), room('sa-1234', addresses: [v4, v6])]);
    expect(rooms, hasLength(1));
    expect(rooms.single.addresses, [v6, v4]);
    expect(rooms.single.connectAddress, '192.168.1.5');
  });

  test('farklı odalar korunur; adı boş kayıtlar ana makine ve emojiyle ayrılır', () {
    final rooms = LanRoom.dedupe([room('sa-1'), room('sa-2'), room('', host: 'a.local'), room('', host: 'a.local')]);
    expect(rooms.map((r) => r.name), ['sa-1', 'sa-2', '']);
  });
}
