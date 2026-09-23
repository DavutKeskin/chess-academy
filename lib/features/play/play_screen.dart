import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/captured_material.dart';
import '../../core/feedback.dart';
import '../../core/game_clock.dart';
import '../../core/game_store.dart';
import '../../core/opponent.dart';
import '../../core/progress_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/captured_pieces.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/l10n.dart';
import 'lan_lobby_screen.dart';
import 'replay_screen.dart';

String levelName(AppLocalizations t, int level) => switch (level) {
      1 => t.level1,
      2 => t.level2,
      3 => t.level3,
      4 => t.level4,
      _ => t.level5,
    };

String levelHint(AppLocalizations t, int level) => switch (level) {
      1 => t.levelHint1,
      2 => t.levelHint2,
      3 => t.levelHint3,
      4 => t.levelHint4,
      _ => t.levelHint5,
    };

/// Süre seçeneğinin kısa adı ("5 dk", "3 dk + 2 sn", "Süresiz").
String timeControlLabel(AppLocalizations t, TimeControl tc) {
  if (tc.isUnlimited) return t.timeUnlimited;
  return tc.incrementSeconds == 0 ? t.timeMinutes(tc.minutes) : t.timeMinutesInc(tc.minutes, tc.incrementSeconds);
}

String timeControlHint(AppLocalizations t, TimeControl tc) {
  if (tc.isUnlimited) return t.timeUnlimitedHint;
  return tc.incrementSeconds == 0 ? t.timeHint(tc.minutes) : t.timeIncHint(tc.incrementSeconds);
}

/// Sonucun kısa adı; süreyle bitmiş, bırakılmış ya da bağlantı kopmuşsa parantez içinde belirtilir.
String resultLabel(AppLocalizations t, GameRecord g) {
  final base = switch (g.result) {
    'win' => t.resultWinShort,
    'loss' => t.resultLoseShort,
    _ => t.resultDrawShort,
  };
  if (g.endedOnTime) return '$base (${t.onTimeSuffix})';
  if (g.resigned) return '$base (${t.resignedSuffix})';
  if (g.disconnected) return '$base (${t.lanDisconnectedSuffix})';
  return base;
}

/// Oyun özeti: "Seviye 3 · Kazandın" ya da Wi‑Fi oyununda "Arkadaş (Wi‑Fi) · Kazandın".
String gameSummaryLabel(AppLocalizations t, GameRecord g) {
  final result = resultLabel(t, g);
  return g.isVsFriend ? '${t.lanFriend} · $result' : t.gameSummary(g.level, result);
}

/// Rakip satırının adı: bilgisayar ya da arkadaş.
String opponentLabel(AppLocalizations t, GameRecord g) => g.isVsFriend ? t.lanFriendShort : t.clockComputer;

/// Oyun ekranı: bilgisayara karşı (varsayılan yapıcı) ya da hazır bir [Opponent] ile
/// (örneğin Wi‑Fi üstünden arkadaş). Ekran rakibi sahiplenir ve kapanırken bırakır.
class PlayScreen extends StatefulWidget {
  /// [opponent] verilirse bilgisayar yerine o oynar (testler ve mağaza ekran görüntüleri için).
  const PlayScreen({
    super.key,
    required this.level,
    required this.playerSide,
    this.timeControl = TimeControl.unlimited,
    this.opponent,
  });

  /// Bağlantısı kurulmuş uzak rakiple oyun; süresiz, seviye 0.
  const PlayScreen.remote({super.key, required Opponent this.opponent, required this.playerSide})
      : level = 0,
        timeControl = TimeControl.unlimited;

  final int level;
  final Side playerSide;
  final TimeControl timeControl;
  final Opponent? opponent;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  late ChessboardController _controller;
  Position _position = Chess.initial;
  Move? _lastMove;
  late final Opponent _opponent;
  StreamSubscription<OpponentEvent>? _events;
  bool _ready = false;
  GameClock? _clock;
  bool _thinking = false;
  bool _finished = false;
  String? _endedBy; // 'timeout' | 'resign' | 'disconnect'

  /// Her yeni oyunda artar; önceki oyun için gelen bilgisayar hamlesi bununla ayıklanır.
  int _gameSeq = 0;
  final List<String> _sanMoves = [];
  final List<String> _uciMoves = [];
  GameRecord? _record;
  final _movesScroll = ScrollController();

  Side get _botSide => widget.playerSide.opposite;
  bool get _remote => _opponent.isRemote;

  @override
  void initState() {
    super.initState();
    _opponent = widget.opponent ?? BotOpponent(widget.level);
    _events = _opponent.events.listen(_onOpponentEvent);
    _controller = ChessboardController(game: _gameData());
    if (!widget.timeControl.isUnlimited) {
      _clock = GameClock(widget.timeControl, onFlag: _onFlag);
      WidgetsBinding.instance.addObserver(this);
    }
    _startOpponent();
  }

  Future<void> _startOpponent() async {
    await _opponent.ready;
    if (!mounted) return;
    setState(() => _ready = true);
    // Rakip hazır: tahtayı oynanabilir duruma al (aksi halde dokunma çalışmaz).
    _controller.updatePosition(_gameData(), animate: false);
    if (_position.turn != widget.playerSide) _botMove();
  }

  /// Uzak rakipten hamle dışı olay: bırakma ya da kopuş. Oyun bittiyse yok sayılır.
  void _onOpponentEvent(OpponentEvent e) {
    if (_finished || !mounted) return;
    switch (e) {
      case OpponentResigned():
        _finish(winner: widget.playerSide, endedBy: 'resign');
      case OpponentDisconnected():
        _finish(winner: null, endedBy: 'disconnect');
    }
    _controller.updatePosition(_gameData());
    setState(() {});
  }

  @override
  void dispose() {
    if (_clock != null) WidgetsBinding.instance.removeObserver(this);
    _clock?.dispose();
    _controller.dispose();
    _movesScroll.dispose();
    _events?.cancel();
    _opponent.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Çocuk uygulamayı kapatıp dönerse süresi arka planda erimesin.
    if (state == AppLifecycleState.paused) {
      _clock?.pause();
    } else if (state == AppLifecycleState.resumed && !_finished) {
      _clock?.resume();
    }
  }

  GameData _gameData() => GameData(
        fen: _position.fen,
        lastMove: _lastMove,
        playerSide: _finished || _thinking || !_ready
            ? PlayerSide.none
            : (widget.playerSide == Side.white ? PlayerSide.white : PlayerSide.black),
        sideToMove: _position.turn,
        kingSquareInCheck: _position.isCheck ? _position.board.kingOf(_position.turn) : null,
        validMoves: makeLegalMoves(_position),
      );

  void _apply(Move move) {
    final mover = _position.turn;
    final captured = _position.board.pieceAt(move.to) != null;
    final (next, san) = _position.makeSan(move);
    _position = next;
    _lastMove = move;
    _sanMoves.add(san);
    _uciMoves.add(move.uci);
    if (_position.isGameOver) {
      _finish(winner: _position.outcome?.winner);
    } else {
      _clock?.press(mover);
      AppFeedback.instance.move(capture: captured);
    }
    _controller.updatePosition(_gameData());
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_movesScroll.hasClients) {
        _movesScroll.animateTo(_movesScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  /// Oyunu bitirir, sonucu kaydeder. [winner] null ise berabere.
  /// Arkadaşla oyun ilerlemeye (istatistik, rozet) sayılmaz; yalnızca kayda girer.
  /// Hiç hamle yapılmadan biten oyun (ör. bağlantı hemen koptu) kaydedilmez.
  void _finish({required Side? winner, String? endedBy}) {
    _finished = true;
    _thinking = false;
    _endedBy = endedBy;
    _clock?.stop();
    final won = winner == widget.playerSide;
    if (!_remote) ProgressStore.instance.recordGame(won: won);
    if (_uciMoves.isEmpty) return;
    final record = GameRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playedAt: DateTime.now(),
      level: widget.level,
      playerIsWhite: widget.playerSide == Side.white,
      uciMoves: List.of(_uciMoves),
      sanMoves: List.of(_sanMoves),
      result: winner == null ? 'draw' : (won ? 'win' : 'loss'),
      timeControl: widget.timeControl.isUnlimited ? null : widget.timeControl.code,
      endedBy: endedBy,
    );
    _record = record;
    GameStore.instance.add(record);
    if (won) {
      AppFeedback.instance.win();
    } else {
      AppFeedback.instance.lose();
    }
  }

  /// [side] tarafının süresi bitti. Karşı tarafın mat edecek taşı yoksa berabere.
  void _onFlag(Side side) {
    if (_finished || !mounted) return;
    final winner = side.opposite;
    _finish(winner: _position.hasInsufficientMaterial(winner) ? null : winner, endedBy: 'timeout');
    _controller.updatePosition(_gameData());
    setState(() {});
  }

  void _onUserMove(Move move, {bool? viaDragAndDrop}) {
    if (_thinking || _finished) return;
    _apply(move);
    _opponent.onLocalMove(move, _uciMoves.length - 1);
    if (!_finished) _botMove();
  }

  /// Rakibin hamlesini ister (bilgisayar hesaplar, arkadaş ağdan gönderir).
  Future<void> _botMove() async {
    if (!_ready) return;
    setState(() => _thinking = true);
    _controller.updatePosition(_gameData());
    // Süreli oyunda bilgisayar kalan süresinin küçük bir payını kullanır.
    final clock = _clock;
    final budget = clock == null ? null : clock.remaining(_botSide).inMilliseconds ~/ 20;
    final seq = _gameSeq;
    final move = await _opponent.nextMove(_position, maxTimeMs: budget);
    // Beklerken oyun bittiyse ya da yeniden başladıysa bu hamle artık geçersiz.
    if (!mounted || _finished || seq != _gameSeq || move == null) return;
    _thinking = false;
    _apply(move);
  }

  /// Oyuncu en az bir hamle yaptıysa oyun sürüyor sayılır; çıkmak ya da yeniden başlamak kayıp.
  bool get _inProgress => !_finished && _uciMoves.length >= (widget.playerSide == Side.white ? 1 : 2);

  /// Onay alınırsa oyunu bırakılmış (kayıp) olarak bitirir.
  Future<bool> _confirmResign() async {
    final t = context.t;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.resignTitle),
        content: Text(t.resignBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.keepPlaying)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t.resign)),
        ],
      ),
    );
    if (ok != true || !mounted || !_inProgress) return false;
    _opponent.resign();
    _finish(winner: _botSide, endedBy: 'resign');
    _controller.updatePosition(_gameData());
    setState(() {});
    return true;
  }

  Future<void> _onRestartPressed() async {
    if (_inProgress && !await _confirmResign()) return;
    if (mounted) _restart();
  }

  void _restart() {
    _gameSeq++;
    setState(() {
      _position = Chess.initial;
      _lastMove = null;
      _finished = false;
      _endedBy = null;
      _thinking = false;
      _sanMoves.clear();
      _uciMoves.clear();
      _record = null;
    });
    _clock?.reset();
    _controller.updatePosition(_gameData(), animate: false);
    if (_position.turn != widget.playerSide) _botMove();
  }

  /// İlk üç oyunda, bilgisayarın ilk iki hamlesinden sonra son hamle vurgusunu anlatır.
  bool get _showLastMoveHint =>
      !_remote && _lastMove != null && _sanMoves.length <= 4 && ProgressStore.instance.gamesPlayed < 3;

  (String, BannerTone, IconData?) _status(AppLocalizations t) {
    if (_finished) {
      final winner = _record?.result;
      if (_endedBy == 'disconnect') return (t.lanConnectionLost, BannerTone.error, Icons.wifi_off_rounded);
      if (_endedBy == 'resign') {
        return winner == 'win'
            ? (t.lanFriendResigned, BannerTone.success, null)
            : (t.resultResigned, BannerTone.error, Icons.flag_rounded);
      }
      if (_endedBy == 'timeout') {
        return switch (winner) {
          'win' => (t.resultWinTimeout, BannerTone.success, null),
          'loss' => (t.resultLoseTimeout, BannerTone.error, Icons.timer_off_rounded),
          _ => (t.resultDrawTimeout, BannerTone.info, Icons.handshake_rounded),
        };
      }
      return switch (winner) {
        'win' => (t.resultWin, BannerTone.success, null),
        'loss' => (_remote ? t.lanFriendWon : t.resultLose, BannerTone.error, Icons.sentiment_neutral_rounded),
        _ => (t.resultDraw, BannerTone.info, Icons.handshake_rounded),
      };
    }
    if (!_ready) return (t.opponentPreparing, BannerTone.info, null);
    if (_thinking) {
      return _remote
          ? (t.lanFriendThinking, BannerTone.info, Icons.hourglass_top_rounded)
          : (t.computerThinking, BannerTone.info, Icons.psychology_rounded);
    }
    return _position.isCheck
        ? (t.checkYourTurn, BannerTone.neutral, Icons.warning_amber_rounded)
        : (_showLastMoveHint ? t.yourTurnLastMoveHint : t.yourTurn, BannerTone.neutral, null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (text, tone, icon) = _status(t);
    final clock = _clock;
    final material = CapturedMaterial.of(_position.board);
    return PopScope(
      canPop: !_inProgress,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmResign() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_remote ? t.lanPlayWithFriend : t.levelTitle(widget.level, levelName(t, widget.level))),
          actions: [
            if (_inProgress)
              IconButton(tooltip: t.resign, onPressed: _confirmResign, icon: const Icon(Icons.flag_outlined)),
            if (!_remote)
              IconButton(tooltip: t.restart, onPressed: _onRestartPressed, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: StatusBanner(text: text, tone: tone, icon: icon),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: _PlayerRow(
                  clock: clock,
                  side: _botSide,
                  label: _remote ? t.lanFriendShort : t.clockComputer,
                  material: material,
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, c) => Chessboard(
                        controller: _controller,
                        size: min(c.maxWidth, c.maxHeight),
                        settings: SettingsStore.instance.boardSettings,
                        orientation: widget.playerSide,
                        onMove: _onUserMove,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: _PlayerRow(clock: clock, side: widget.playerSide, label: t.clockYou, material: material),
              ),
              SizedBox(
                height: 40,
                child: _sanMoves.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: _movesScroll,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _sanMoves.length,
                        itemBuilder: (context, i) => Center(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Text(
                              i.isEven ? '${i ~/ 2 + 1}. ${_sanMoves[i]}' : _sanMoves[i],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: i == _sanMoves.length - 1 ? FontWeight.w800 : FontWeight.w500,
                                color: i == _sanMoves.length - 1 ? AppColors.ink : AppColors.inkMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: _finished
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _record == null
                                  ? null
                                  : () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(builder: (_) => ReplayScreen(game: _record!)),
                                      ),
                              icon: const Icon(Icons.history_rounded),
                              label: Text(t.reviewGame),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            // Wi‑Fi oyununda yeniden başlatma yok: lobiye dönülür.
                            child: _remote
                                ? FilledButton.icon(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    label: Text(t.lanNewGame),
                                  )
                                : FilledButton.icon(
                                    onPressed: _restart,
                                    icon: const Icon(Icons.replay_rounded),
                                    label: Text(t.playAgain),
                                  ),
                          ),
                        ],
                      )
                    : const SizedBox(height: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir oyuncunun satırı: adı, aldığı taşlar ve süreli oyunda saati.
class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.clock, required this.side, required this.label, required this.material});
  final GameClock? clock;
  final Side side;
  final String label;
  final CapturedMaterial material;

  @override
  Widget build(BuildContext context) {
    final clock = this.clock;
    if (clock == null) {
      return PlayerMaterialRow(label: label, side: side, material: material, active: true);
    }
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) => PlayerMaterialRow(
        label: label,
        side: side,
        material: material,
        active: clock.running == side,
        trailing: _ClockPill(clock: clock, side: side),
      ),
    );
  }
}

/// Kalan süre. Sayan taraf lacivert, son 10 saniye kırmızı.
class _ClockPill extends StatelessWidget {
  const _ClockPill({required this.clock, required this.side});
  final GameClock clock;
  final Side side;

  @override
  Widget build(BuildContext context) {
    final remaining = clock.remaining(side);
    final active = clock.running == side;
    final low = remaining < const Duration(seconds: 10);
    final bg = low ? AppColors.error : (active ? AppColors.hero : AppColors.surfaceContainer);
    final fg = low || active ? Colors.white : AppColors.inkMuted;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(low ? Icons.timer_rounded : Icons.timer_outlined, size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            formatClock(remaining),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seviye ve renk seçim ekranı; altta son oyunlar.
class PlaySetupScreen extends StatefulWidget {
  const PlaySetupScreen({super.key});

  @override
  State<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends State<PlaySetupScreen> {
  int _level = SettingsStore.instance.suggestedBotLevel;
  Side _side = Side.white;
  TimeControl _time = TimeControl.parse(SettingsStore.instance.timeControl);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final pieces = SettingsStore.instance.pieces.assets;
    return Scaffold(
      appBar: AppBar(title: Text(t.vsComputer)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text(t.opponentLevel, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (var i = 1; i <= 5; i++) ...[
            _LevelTile(level: i, selected: _level == i, onTap: () => setState(() => _level = i)),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Text(t.whichColor, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SideCard(
                  label: t.white,
                  hint: t.youMoveFirst,
                  image: pieces[PieceKind.whiteKing]!,
                  selected: _side == Side.white,
                  onTap: () => setState(() => _side = Side.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SideCard(
                  label: t.black,
                  hint: t.computerStarts,
                  image: pieces[PieceKind.blackKing]!,
                  selected: _side == Side.black,
                  onTap: () => setState(() => _side = Side.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(t.timeControl, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tc in TimeControl.presets)
                ChoiceChip(
                  label: Text(timeControlLabel(t, tc)),
                  avatar: tc.isUnlimited ? const Icon(Icons.all_inclusive_rounded, size: 18) : const Icon(Icons.timer_outlined, size: 18),
                  selected: _time == tc,
                  onSelected: (_) => setState(() => _time = tc),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(timeControlHint(t, _time), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              SettingsStore.instance.setTimeControl(_time.isUnlimited ? null : _time.code);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlayScreen(level: _level, playerSide: _side, timeControl: _time),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(t.startGame),
          ),
          const SizedBox(height: 16),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.play.withValues(alpha: 0.15),
                child: Icon(Icons.wifi_rounded, color: AppColors.play),
              ),
              title: Text(t.lanPlayWithFriend, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(t.lanPlayWithFriendHint),
              trailing: Icon(Icons.chevron_right_rounded, color: AppColors.navy),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LanLobbyScreen()),
              ),
            ),
          ),
          const SizedBox(height: 28),
          ListenableBuilder(
            listenable: GameStore.instance,
            builder: (context, _) {
              final games = GameStore.instance.games;
              if (games.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.recentGames, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  for (final g in games.take(5)) ...[
                    _GameTile(game: g),
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});
  final GameRecord game;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (resultText, color) = switch (game.result) {
      'win' => (t.resultWinShort, AppColors.success),
      'loss' => (t.resultLoseShort, AppColors.error),
      _ => (t.resultDrawShort, AppColors.info),
    };
    // Bitiş şekli sonuç rozetine değil alt satıra: başlık tek satırda kalsın.
    final endedBy = game.endedOnTime
        ? t.onTimeSuffix
        : game.resigned
            ? t.resignedSuffix
            : game.disconnected
                ? t.lanDisconnectedSuffix
                : null;
    final d = game.playedAt;
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final details = [
      ?endedBy,
      t.movesCount(game.sanMoves.length),
      if (game.isTimed) timeControlLabel(t, TimeControl.parse(game.timeControl)),
      date,
    ].map((e) => e.replaceAll(' ', '\u00A0')).join(' · '); // satır yalnızca ayraçlarda kırılsın
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 2, 10, 2),
        // İkon rakibi (bilgisayar / Wi‑Fi), rengi sonucu gösterir.
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(game.isVsFriend ? Icons.wifi_rounded : Icons.smart_toy_outlined, color: color, size: 22),
        ),
        title: Text(
          game.isVsFriend ? t.lanFriend : t.levelTitle(game.level, levelName(t, game.level)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text.rich(
          TextSpan(children: [
            TextSpan(text: resultText, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            TextSpan(text: ' · $details'),
          ]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.inkMuted),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ReplayScreen(game: game)),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.selected, required this.onTap});
  final int level;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Material(
      color: selected ? AppColors.navyLight : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.navy : AppColors.outline, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: selected ? AppColors.hero : AppColors.surfaceContainer, shape: BoxShape.circle),
                child: Text('$level', style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.ink)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(levelName(t, level), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text(levelHint(t, level), style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Row(
                children: [
                  for (var s = 1; s <= 5; s++)
                    Icon(s <= level ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 16, color: s <= level ? AppColors.gold : AppColors.inkMuted.withValues(alpha: 0.35)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.hint, required this.image, required this.selected, required this.onTap});
  final String label;
  final String hint;
  final ImageProvider image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navyLight : AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.navy : AppColors.outline, width: selected ? 2 : 1),
          ),
          child: Column(
            children: [
              Image(image: image, width: 64, height: 64),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(hint, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
