import 'dart:async';
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/dev_flags.dart';
import '../../core/net/lan/lan_discovery.dart';
import '../../core/net/lan/lan_host.dart';
import '../../core/net/lan/lan_session.dart';
import '../../core/net/lan/protocol.dart';
import '../../core/net/lan/remote_opponent.dart';
import '../../core/net/lan/room_emoji.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/l10n.dart';
import 'play_screen.dart';

/// Renk kodunun ('w' | 'b' | 'r') görünen adı.
String _sideName(AppLocalizations t, String code) => switch (code) {
      'w' => t.white,
      'b' => t.black,
      _ => t.lanRandomColor,
    };

/// Kurulan oturumla oyun ekranını açar (bu ekranın yerine).
void _openGame(BuildContext context, LanSession session) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(
      builder: (_) => PlayScreen.remote(opponent: RemoteOpponent(session), playerSide: session.localSide),
    ),
  );
}

/// Arkadaşla oyun girişi: oda kur ya da odaya katıl.
class LanLobbyScreen extends StatelessWidget {
  const LanLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // mDNS olmayan platformda (Linux) yalnızca geliştirme için IP ile bağlanma kalır.
    final enabled = lanDiscoverySupported || kDebugMode;
    return Scaffold(
      appBar: AppBar(title: Text(t.lanPlayWithFriend)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (!lanDiscoverySupported) ...[
            StatusBanner(text: t.lanUnsupported, tone: BannerTone.error, icon: Icons.wifi_off_rounded),
            const SizedBox(height: 12),
          ],
          _ActionCard(
            icon: Icons.add_home_rounded,
            title: t.lanCreateRoom,
            hint: t.lanCreateRoomHint,
            onTap: enabled
                ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LanHostScreen()))
                : null,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            icon: Icons.login_rounded,
            title: t.lanJoinRoom,
            hint: t.lanJoinRoomHint,
            onTap: enabled
                ? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LanJoinScreen()))
                : null,
          ),
          const SizedBox(height: 20),
          StatusBanner(text: t.lanSameWifiHelp, tone: BannerTone.info, icon: Icons.wifi_rounded),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.hint, required this.onTap});
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.hero, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(hint, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.navy),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ev sahibi: renk seçer, odanın emojisi görünür, konuk beklenir.
class LanHostScreen extends StatefulWidget {
  const LanHostScreen({super.key});

  @override
  State<LanHostScreen> createState() => _LanHostScreenState();
}

class _LanHostScreenState extends State<LanHostScreen> {
  /// 'w' | 'b' | 'r'
  String _choice = 'r';
  final List<int> _emoji = randomRoomEmoji();
  LanHost? _host;
  bool _failed = false;
  List<String> _debugAddresses = const [];

  @override
  void initState() {
    super.initState();
    _start();
    if (kDevUi) _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      if (!mounted) return;
      setState(() => _debugAddresses = [for (final i in ifs) for (final a in i.addresses) a.address]);
    } catch (_) {}
  }

  Future<void> _start() async {
    final old = _host;
    _host = null;
    await old?.close();
    final side = switch (_choice) { 'w' => Side.white, 'b' => Side.black, _ => null };
    final host = LanHost(sideChoice: side, emoji: _emoji);
    try {
      await host.start();
    } catch (e) {
      debugPrint('LanHost start failed: $e');
      await host.close();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await host.close();
      return;
    }
    setState(() {
      _host = host;
      _failed = false;
    });
    debugPrint('LAN room listening on port ${host.port}');
    try {
      final session = await host.guest;
      if (!mounted) {
        await session.close();
        return;
      }
      _openGame(context, session);
    } on LanHandshakeException {
      // Oda kapatıldı (ekran kapanırken); yapılacak bir şey yok.
    }
  }

  @override
  void dispose() {
    _host?.close();
    super.dispose();
  }

  void _pick(String code) {
    if (_choice == code) return;
    setState(() => _choice = code);
    // Renk duyuruda yer aldığı için oda yeniden kurulur.
    _start();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final host = _host;
    return Scaffold(
      appBar: AppBar(title: Text(t.lanCreateRoom)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(t.whichColor, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, label, hint) in [
                ('w', t.white, t.youMoveFirst),
                ('b', t.black, t.lanFriendStarts),
                ('r', t.lanRandomColor, t.lanRandomHint),
              ])
                ChoiceChip(
                  label: Text(label),
                  tooltip: hint,
                  selected: _choice == code,
                  onSelected: (_) => _pick(code),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text(t.lanRoomSign, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(t.lanRoomSignHint, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.outline),
            ),
            child: Text(
              roomEmojiText(_emoji),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 56),
            ),
          ),
          const SizedBox(height: 24),
          if (_failed)
            StatusBanner(text: t.lanStartFailed, tone: BannerTone.error, icon: Icons.wifi_off_rounded)
          else
            StatusBanner(text: t.lanWaitingForFriend, tone: BannerTone.info, icon: Icons.hourglass_top_rounded),
          if (kDevUi && host != null) ...[
            const SizedBox(height: 8),
            // Yalnızca geliştirme: mDNS olmadan IP:port ile bağlanmak için.
            Text(
              'debug: ${_debugAddresses.join(', ')} : ${host.port}',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            label: Text(t.cancel),
          ),
          const SizedBox(height: 16),
          Text(t.lanSameWifiHelp, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Konuk: ağdaki odalar emoji kartları olarak listelenir, dokununca bağlanır.
class LanJoinScreen extends StatefulWidget {
  const LanJoinScreen({super.key});

  @override
  State<LanJoinScreen> createState() => _LanJoinScreenState();
}

class _LanJoinScreenState extends State<LanJoinScreen> {
  final RoomFinder _finder = RoomFinder.platform();
  bool _connecting = false;
  String? _error;
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    _finder.start().catchError((Object e) => debugPrint('discovery failed: $e'));
  }

  @override
  void dispose() {
    _finder.dispose();
    _manual.dispose();
    super.dispose();
  }

  Future<void> _connect(String address, int port) async {
    if (_connecting) return;
    final t = context.t;
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final session = await LanGuest.connect(address, port);
      if (!mounted) {
        await session.close();
        return;
      }
      _openGame(context, session);
    } on LanHandshakeException catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e.code == ErrorMessage.proto ? t.lanVersionMismatch : t.lanJoinFailed;
      });
    } catch (e) {
      debugPrint('LAN connect failed: $e');
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = t.lanJoinFailed;
      });
    }
  }

  void _connectManual() {
    final parts = _manual.text.trim().split(':');
    final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (port != null) _connect(parts[0], port);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: AppBar(title: Text(t.lanJoinRoom)),
      body: ListenableBuilder(
        listenable: _finder,
        builder: (context, _) {
          final rooms = _finder.rooms;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              if (_error != null) ...[
                StatusBanner(text: _error!, tone: BannerTone.error, icon: Icons.wifi_off_rounded),
                const SizedBox(height: 12),
              ],
              if (_connecting)
                StatusBanner(text: t.lanConnecting, tone: BannerTone.info)
              else if (rooms.isEmpty)
                StatusBanner(text: t.lanSearching, tone: BannerTone.info, icon: Icons.wifi_find_rounded)
              else
                Text(t.lanRoomsFound, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final room in rooms) ...[
                _RoomCard(
                  room: room,
                  onTap: _connecting || !room.isCompatible || room.connectAddress == null
                      ? null
                      : () => _connect(room.connectAddress!, room.port),
                ),
                const SizedBox(height: 10),
              ],
              if (rooms.isEmpty && !_connecting) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text('🐶 🐱 🐰', style: TextStyle(fontSize: 40, color: AppColors.inkMuted.withValues(alpha: 0.5))),
                ),
                const SizedBox(height: 12),
                Text(t.lanNoRooms, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 20),
              Text(t.lanSameWifiHelp, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              if (kDevUi) ...[
                // Yalnızca geliştirme: mDNS olmadan doğrudan bağlanma.
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'debug: IP:port', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      // Row içinde tam genişlik isteyen tema stili yerleşim hatası verir.
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                      onPressed: _connecting ? null : _connectManual,
                      child: const Text('Bağlan'),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});
  final LanRoom room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final enabled = onTap != null;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: enabled ? AppColors.navy : AppColors.outline, width: enabled ? 2 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.emoji.isEmpty ? '❔' : roomEmojiText(room.emoji),
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      room.isCompatible ? t.lanHostSide(_sideName(t, room.hostSide)) : t.lanVersionMismatch,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: room.isCompatible ? AppColors.inkMuted : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded, size: 40, color: enabled ? AppColors.hero : AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
