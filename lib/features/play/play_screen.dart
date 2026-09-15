import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/bot/bot.dart';
import '../../core/feedback.dart';
import '../../core/game_clock.dart';
import '../../core/game_store.dart';
import '../../core/progress_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/l10n.dart';
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

/// Sonucun kısa adı; süreyle bitmişse "(süre)" eklenir.
String resultLabel(AppLocalizations t, GameRecord g) {
  final base = switch (g.result) {
    'win' => t.resultWinShort,
    'loss' => t.resultLoseShort,
    _ => t.resultDrawShort,
  };
  return g.endedOnTime ? '$base (${t.onTimeSuffix})' : base;
}

/// Bilgisayara karşı oyun ekranı.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.level,
    required this.playerSide,
    this.timeControl = TimeControl.unlimited,
  });

  final int level;
  final Side playerSide;
  final TimeControl timeControl;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with WidgetsBindingObserver {
  late ChessboardController _controller;
  Position _position = Chess.initial;
  Move? _lastMove;
  Bot? _bot;
  GameClock? _clock;
  bool _thinking = false;
  bool _finished = false;
  bool _timedOut = false;
  final List<String> _sanMoves = [];
  final List<String> _uciMoves = [];
  GameRecord? _record;
  final _movesScroll = ScrollController();

  Side get _botSide => widget.playerSide.opposite;

  @override
  void initState() {
    super.initState();
    _controller = ChessboardController(game: _gameData());
    if (!widget.timeControl.isUnlimited) {
      _clock = GameClock(widget.timeControl, onFlag: _onFlag);
      WidgetsBinding.instance.addObserver(this);
    }
    _startBot();
  }

  Future<void> _startBot() async {
    final bot = await Bot.create(widget.level);
    if (!mounted) {
      await bot.dispose();
      return;
    }
    setState(() => _bot = bot);
    // Rakip hazır: tahtayı oynanabilir duruma al (aksi halde dokunma çalışmaz).
    _controller.updatePosition(_gameData(), animate: false);
    if (_position.turn != widget.playerSide) _botMove();
  }

  @override
  void dispose() {
    if (_clock != null) WidgetsBinding.instance.removeObserver(this);
    _clock?.dispose();
    _controller.dispose();
    _movesScroll.dispose();
    _bot?.dispose();
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
        playerSide: _finished || _thinking || _bot == null
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
  void _finish({required Side? winner, bool onTime = false}) {
    _finished = true;
    _timedOut = onTime;
    _clock?.stop();
    final won = winner == widget.playerSide;
    ProgressStore.instance.recordGame(won: won);
    final record = GameRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playedAt: DateTime.now(),
      level: widget.level,
      playerIsWhite: widget.playerSide == Side.white,
      uciMoves: List.of(_uciMoves),
      sanMoves: List.of(_sanMoves),
      result: winner == null ? 'draw' : (won ? 'win' : 'loss'),
      timeControl: widget.timeControl.isUnlimited ? null : widget.timeControl.code,
      endedBy: onTime ? 'timeout' : null,
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
    _finish(winner: _position.hasInsufficientMaterial(winner) ? null : winner, onTime: true);
    _thinking = false;
    _controller.updatePosition(_gameData());
    setState(() {});
  }

  void _onUserMove(Move move, {bool? viaDragAndDrop}) {
    if (_thinking || _finished) return;
    _apply(move);
    if (!_finished) _botMove();
  }

  Future<void> _botMove() async {
    final bot = _bot;
    if (bot == null) return;
    setState(() => _thinking = true);
    _controller.updatePosition(_gameData());
    // Süreli oyunda bilgisayar kalan süresinin küçük bir payını kullanır.
    final clock = _clock;
    final budget = clock == null ? null : clock.remaining(_botSide).inMilliseconds ~/ 20;
    final move = await bot.bestMove(_position, maxTimeMs: budget);
    if (!mounted || _finished) return;
    _thinking = false;
    _apply(move);
  }

  void _restart() {
    setState(() {
      _position = Chess.initial;
      _lastMove = null;
      _finished = false;
      _timedOut = false;
      _thinking = false;
      _sanMoves.clear();
      _uciMoves.clear();
      _record = null;
    });
    _clock?.reset();
    _controller.updatePosition(_gameData(), animate: false);
    if (_position.turn != widget.playerSide) _botMove();
  }

  (String, BannerTone, IconData?) _status(AppLocalizations t) {
    if (_finished) {
      final winner = _record?.result;
      if (_timedOut) {
        return switch (winner) {
          'win' => (t.resultWinTimeout, BannerTone.success, null),
          'loss' => (t.resultLoseTimeout, BannerTone.error, Icons.timer_off_rounded),
          _ => (t.resultDrawTimeout, BannerTone.info, Icons.handshake_rounded),
        };
      }
      return switch (winner) {
        'win' => (t.resultWin, BannerTone.success, null),
        'loss' => (t.resultLose, BannerTone.error, Icons.sentiment_neutral_rounded),
        _ => (t.resultDraw, BannerTone.info, Icons.handshake_rounded),
      };
    }
    if (_bot == null) return (t.opponentPreparing, BannerTone.info, null);
    if (_thinking) return (t.computerThinking, BannerTone.info, Icons.psychology_rounded);
    return _position.isCheck
        ? (t.checkYourTurn, BannerTone.neutral, Icons.warning_amber_rounded)
        : (t.yourTurn, BannerTone.neutral, null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final (text, tone, icon) = _status(t);
    final clock = _clock;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.levelTitle(widget.level, levelName(t, widget.level))),
        actions: [
          IconButton(tooltip: t.restart, onPressed: _restart, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: StatusBanner(text: text, tone: tone, icon: icon),
            ),
            if (clock != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: _ClockRow(clock: clock, side: _botSide, label: t.clockComputer),
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
            if (clock != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: _ClockRow(clock: clock, side: widget.playerSide, label: t.clockYou),
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
                          child: FilledButton.icon(
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
    );
  }
}

/// Bir tarafın saati: etiket solda, kalan süre sağda. Sayan taraf lacivert,
/// son 10 saniye kırmızı.
class _ClockRow extends StatelessWidget {
  const _ClockRow({required this.clock, required this.side, required this.label});
  final GameClock clock;
  final Side side;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: clock,
      builder: (context, _) {
        final remaining = clock.remaining(side);
        final active = clock.running == side;
        final low = remaining < const Duration(seconds: 10);
        final bg = low ? AppColors.error : (active ? AppColors.navy : AppColors.surfaceContainer);
        final fg = low || active ? Colors.white : AppColors.inkMuted;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: active ? AppColors.ink : AppColors.inkMuted)),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            ),
          ],
        );
      },
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
    final label = resultLabel(t, game);
    final (color, icon) = switch (game.result) {
      'win' => (AppColors.success, Icons.emoji_events_rounded),
      'loss' => (AppColors.error, Icons.sentiment_neutral_rounded),
      _ => (AppColors.info, Icons.handshake_rounded),
    };
    final tc = game.isTimed ? ' · ${timeControlLabel(t, TimeControl.parse(game.timeControl))}' : '';
    final d = game.playedAt;
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(t.gameSummary(game.level, label), style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${t.movesCount(game.sanMoves.length)}$tc · $date'),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
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
                decoration: BoxDecoration(color: selected ? AppColors.navy : AppColors.surfaceContainer, shape: BoxShape.circle),
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
                        size: 16, color: s <= level ? AppColors.gold : AppColors.outline),
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
