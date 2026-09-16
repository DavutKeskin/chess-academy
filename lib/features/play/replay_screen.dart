import 'dart:async';
import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/analysis/game_analysis.dart';
import '../../core/captured_material.dart';
import '../../core/engine/engine_service.dart';
import '../../core/game_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/captured_pieces.dart';
import '../../l10n/l10n.dart';
import 'play_screen.dart';

Color qualityColor(MoveQuality q) => switch (q) {
  MoveQuality.best => const Color(0xFF1B7F4B),
  MoveQuality.good => AppColors.success,
  MoveQuality.inaccuracy => const Color(0xFFD9A400),
  MoveQuality.mistake => const Color(0xFFE67E22),
  MoveQuality.blunder => AppColors.error,
};

String qualityLabel(AppLocalizations t, MoveQuality q) => switch (q) {
  MoveQuality.best => t.qualityBest,
  MoveQuality.good => t.qualityGood,
  MoveQuality.inaccuracy => t.qualityInaccuracy,
  MoveQuality.mistake => t.qualityMistake,
  MoveQuality.blunder => t.qualityBlunder,
};

/// Bitmiş bir oyunu hamle hamle izleme ve motor analizi.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({super.key, required this.game});
  final GameRecord game;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  late GameRecord _game;
  late final List<Position> _positions;
  late final List<Move> _moves;
  int _ply = 0;
  final _scroll = ScrollController();

  GameAnalysis? _analysis;
  double? _progress; // null = analiz yapılmıyor
  bool _failed = false;

  // Simülasyon: en iyi devam yolu tahtada oynatılır.
  List<Position>? _simPositions;
  List<Move>? _simMoves;
  List<String>? _simSans;
  int _simIndex = 0;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _analysis = _game.analysis;
    _moves = [for (final u in _game.uciMoves) NormalMove.fromUci(u)];
    final positions = <Position>[Chess.initial];
    for (final m in _moves) {
      positions.add(positions.last.playUnchecked(m));
    }
    _positions = positions;
    _ply = _moves.length;
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  MoveAnalysis? get _current {
    final a = _analysis;
    if (a == null || _ply == 0) return null;
    for (final m in a.moves) {
      if (m.ply == _ply - 1) return m;
    }
    return null;
  }

  /// Konum indeksine göre değerlendirme (oyuncu gözünden), biliniyorsa.
  int? _evalAt(int posIndex) {
    final a = _analysis;
    if (a == null) return null;
    for (final m in a.moves) {
      if (m.ply == posIndex) return m.evalBefore;
      if (m.ply + 1 == posIndex) return m.evalAfter;
    }
    return null;
  }

  void _go(int ply) {
    _stopSim();
    setState(() => _ply = ply.clamp(0, _moves.length));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || _ply == 0) return;
      final target = ((_ply - 1) * 72.0 - 120).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _analyse() async {
    if (_progress != null) return;
    setState(() {
      _progress = 0;
      _failed = false;
    });
    try {
      final result = await GameAnalyzer().analyse(
        _game,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await GameStore.instance.saveAnalysis(_game.id, result);
      if (!mounted) return;
      setState(() {
        _analysis = result;
        _game = _game.withAnalysis(result);
        _progress = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _failed = true;
      });
    }
  }

  void _startSim(MoveAnalysis m) {
    _simTimer?.cancel();
    var pos = _positions[m.ply];
    final positions = <Position>[pos];
    final moves = <Move>[];
    final sans = <String>[];
    for (final u in m.bestPv) {
      final mv = NormalMove.fromUci(u);
      if (!pos.isLegal(mv)) break;
      final (next, san) = pos.makeSan(mv);
      positions.add(next);
      moves.add(mv);
      sans.add(san);
      pos = next;
    }
    if (moves.isEmpty) return;
    setState(() {
      _simPositions = positions;
      _simMoves = moves;
      _simSans = sans;
      _simIndex = 1;
    });
    _simTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) {
      if (!mounted || _simPositions == null) {
        timer.cancel();
        return;
      }
      if (_simIndex >= _simMoves!.length) {
        timer.cancel();
        return;
      }
      setState(() => _simIndex++);
    });
  }

  void _stopSim() {
    _simTimer?.cancel();
    if (_simPositions != null) {
      setState(() {
        _simPositions = null;
        _simMoves = null;
        _simSans = null;
        _simIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final g = _game;
    final resultText = resultLabel(t, g);
    final current = _current;
    final sim = _simPositions;
    final boardPos = sim != null ? sim[_simIndex] : _positions[_ply];
    final boardLast = sim != null
        ? _simMoves![_simIndex - 1]
        : (_ply == 0 ? null : _moves[_ply - 1]);

    final shapes = <Shape>{};
    if (sim == null &&
        current != null &&
        current.quality.index >= MoveQuality.inaccuracy.index) {
      final best = NormalMove.fromUci(current.bestUci);
      final played = NormalMove.fromUci(current.playedUci);
      shapes.add(
        Arrow(
          color: AppColors.error.withValues(alpha: 0.75),
          orig: played.from,
          dest: played.to,
        ),
      );
      shapes.add(
        Arrow(
          color: AppColors.success.withValues(alpha: 0.9),
          orig: best.from,
          dest: best.to,
        ),
      );
    }
    final eval = sim == null ? _evalAt(_ply) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.reviewGame),
        actions: [
          if (_analysis == null &&
              _progress == null &&
              EngineService.isSupported)
            TextButton.icon(
              onPressed: _analyse,
              icon: const Icon(Icons.auto_graph_rounded),
              label: Text(t.analyseGame),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _analysis != null
                  ? _SummaryBar(analysis: _analysis!)
                  : _progress != null
                  ? _ProgressBar(progress: _progress!)
                  : Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${t.gameSummary(g.level, resultText)} · ${t.movesCount(g.sanMoves.length)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  t.analysisFailed,
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_analysis == null &&
                _progress == null &&
                !EngineService.isSupported)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  t.analysisUnavailable,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size = min(
                      c.maxWidth - 22,
                      c.maxHeight - 2 * PlayerMaterialRow.height,
                    );
                    final playerSide = g.playerIsWhite ? Side.white : Side.black;
                    final material = CapturedMaterial.of(boardPos.board);
                    // Oyuncu satırları tahtayla hizalı (soldaki değerlendirme çubuğu kadar içeride).
                    Widget playerRow(Side side, String label) => Padding(
                      padding: const EdgeInsets.only(left: 22),
                      child: SizedBox(
                        width: size,
                        child: PlayerMaterialRow(
                          label: label,
                          side: side,
                          material: material,
                          active: true,
                        ),
                      ),
                    );
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        playerRow(playerSide.opposite, t.clockComputer),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: size,
                              child: _EvalBar(
                                eval: eval,
                                playerIsWhite: g.playerIsWhite,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StaticChessboard(
                              size: size,
                              orientation: playerSide,
                              fen: boardPos.fen,
                              lastMove: boardLast,
                              shapes: shapes,
                              settings: SettingsStore.instance.staticBoardSettings,
                            ),
                          ],
                        ),
                        playerRow(playerSide, t.clockYou),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (sim != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.simulationHint(_simSans!.take(_simIndex).join(' ')),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(onPressed: _stopSim, child: Text(t.stopShowing)),
                  ],
                ),
              )
            else if (current != null)
              _MovePanel(
                analysis: current,
                onShowBetter: () => _startSim(current),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Text(
                  _ply == 0
                      ? t.replayStart
                      : t.replayMove(_ply, g.sanMoves[_ply - 1]),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyDark,
                  ),
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView.builder(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: g.sanMoves.length,
                itemBuilder: (context, i) {
                  final selected = i == _ply - 1 && sim == null;
                  MoveQuality? q;
                  if (_analysis != null) {
                    for (final m in _analysis!.moves) {
                      if (m.ply == i) q = m.quality;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: q == null
                          ? null
                          : CircleAvatar(
                              radius: 5,
                              backgroundColor: qualityColor(q),
                            ),
                      label: Text(
                        i.isEven
                            ? '${i ~/ 2 + 1}. ${g.sanMoves[i]}'
                            : g.sanMoves[i],
                      ),
                      selected: selected,
                      onSelected: (_) => _go(i + 1),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    onPressed: _ply > 0 ? () => _go(0) : null,
                    icon: const Icon(Icons.first_page_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _ply > 0 ? () => _go(_ply - 1) : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _ply < _moves.length
                        ? () => _go(_ply + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _ply < _moves.length
                        ? () => _go(_moves.length)
                        : null,
                    icon: const Icon(Icons.last_page_rounded),
                  ),
                ],
              ),
            ),
            if (_analysis != null)
              _KeyMoments(analysis: _analysis!, onJump: (ply) => _go(ply + 1)),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.analysis});
  final GameAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final a = analysis;
    final acc = a.accuracy.round();
    final color = acc >= 85
        ? AppColors.success
        : (acc >= 65 ? const Color(0xFFD9A400) : AppColors.error);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                t.accuracyValue(acc),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                t.accuracyLabel,
                style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t.countsLine(
              a.count(MoveQuality.blunder),
              a.count(MoveQuality.mistake),
              a.count(MoveQuality.inaccuracy),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          context.t.analysing((progress * 100).round()),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Seçili oyuncu hamlesi için nitelik, daha iyi hamle ve kaçırılan fırsat.
class _MovePanel extends StatelessWidget {
  const _MovePanel({required this.analysis, required this.onShowBetter});
  final MoveAnalysis analysis;
  final VoidCallback onShowBetter;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final m = analysis;
    final color = qualityColor(m.quality);
    final bad = m.quality.index >= MoveQuality.inaccuracy.index;
    final opp = switch (m.opportunity) {
      Opportunity.mate => t.missedMate(m.mateInBefore ?? 1),
      Opportunity.material => t.missedMaterial,
      Opportunity.big => t.missedBig,
      Opportunity.none => null,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: color),
                      const SizedBox(width: 8),
                      Text(
                        qualityLabel(t, m.quality),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.yourMove(m.playedSan),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  if (bad) ...[
                    const SizedBox(height: 2),
                    Text(_lossLine(t, m), style: const TextStyle(fontSize: 14)),
                    if (opp != null)
                      Text(
                        opp,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ] else
                    Text(
                      t.moveWasGood,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (bad && m.bestPv.isNotEmpty)
              FilledButton.tonal(
                onPressed: onShowBetter,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(
                  t.showBetter,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Daha iyisi: Nc8 · 1.5 piyon kaybı" satırı. Mat kaçırıldıysa fırsat metni zaten
/// açıklar; kayıp mat ölçeğindeyse (≥ 8 piyon) sayı yerine sözle anlatılır.
String _lossLine(AppLocalizations t, MoveAnalysis m) {
  final better = t.betterMove(m.bestSan);
  if (m.opportunity == Opportunity.mate) return better;
  if (m.lossCp >= 800) {
    return '$better · ${m.evalBefore >= 300 ? t.lossWinningThrown : t.lossLosesGame}';
  }
  return '$better · ${t.lossCp((m.lossCp / 100).toStringAsFixed(1))}';
}

/// Oyuncu gözünden değerlendirme çubuğu: beyaz kısım oyuncunun payı.
class _EvalBar extends StatelessWidget {
  const _EvalBar({required this.eval, required this.playerIsWhite});
  final int? eval;
  final bool playerIsWhite;

  @override
  Widget build(BuildContext context) {
    final e = eval;
    final share = e == null ? 0.5 : (winPercent(e.clamp(-2000, 2000)) / 100);
    // Tahtada oyuncu altta: oyuncunun payı alttan (açık renk) dolar.
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: AppColors.surfaceContainer,
        child: Column(
          children: [
            Expanded(
              flex: ((1 - share) * 1000).round().clamp(1, 999),
              child: Container(color: const Color(0xFF3A3F4B)),
            ),
            Expanded(
              flex: (share * 1000).round().clamp(1, 999),
              child: Container(
                color: e == null ? AppColors.outline : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyMoments extends StatelessWidget {
  const _KeyMoments({required this.analysis, required this.onJump});
  final GameAnalysis analysis;
  final void Function(int ply) onJump;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final moments = analysis.keyMoments;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.keyMoments, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (moments.isEmpty)
            Text(t.noKeyMoments, style: Theme.of(context).textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in moments)
                  ActionChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: qualityColor(m.quality),
                    ),
                    label: Text(
                      '${m.ply ~/ 2 + 1}. ${m.playedSan} → ${m.bestSan}',
                    ),
                    onPressed: () => onJump(m.ply),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
