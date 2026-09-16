import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/progress_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_banner.dart';
import '../../l10n/l10n.dart';
import 'puzzles.dart';

/// Çok hamleli bulmaca ekranı. [puzzles] listesi içinde [index]'ten başlar,
/// "Sonraki" ile listede ilerler.
class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key, required this.puzzles, required this.index});
  final List<Puzzle> puzzles;
  final int index;

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

enum _Status { playing, opponentMoving, wrong, solved }

class _PuzzleScreenState extends State<PuzzleScreen> {
  late Puzzle _puzzle;
  late Position _position;
  late ChessboardController _controller;
  Move? _lastMove;
  int _step = 0; // çözümde sıradaki hamlenin indeksi
  _Status _status = _Status.playing;
  int _hintLevel = 0; // 0 yok, 1 taş, 2 hedef
  bool _usedHint = false;
  Side _playerSide = Side.white;

  @override
  void initState() {
    super.initState();
    _load();
    _controller = ChessboardController(game: _gameData());
  }

  void _load() {
    _puzzle = widget.puzzles[widget.index];
    _position = Chess.fromSetup(Setup.parseFen(_puzzle.fen));
    _playerSide = _position.turn;
    _lastMove = _puzzle.lastMove != null
        ? NormalMove.fromUci(_puzzle.lastMove!)
        : null;
    _step = 0;
    _status = _Status.playing;
    _hintLevel = 0;
    _usedHint = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLastPlayerMove => _step == _puzzle.moves.length - 1;
  Move get _expected => NormalMove.fromUci(_puzzle.moves[_step]);

  GameData _gameData() => GameData(
    fen: _position.fen,
    lastMove: _lastMove,
    playerSide: _status == _Status.playing
        ? (_playerSide == Side.white ? PlayerSide.white : PlayerSide.black)
        : PlayerSide.none,
    sideToMove: _position.turn,
    kingSquareInCheck: _position.isCheck
        ? _position.board.kingOf(_position.turn)
        : null,
    validMoves: makeLegalMoves(_position),
  );

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (_status != _Status.playing) return;
    final next = _position.playUnchecked(move);
    // Son hamlede herhangi bir mat kabul edilir; ara hamleler çözümle birebir olmalı.
    final correct = _isLastPlayerMove
        ? next.isCheckmate
        : _sameMove(move, _expected);
    if (!correct) {
      AppFeedback.instance.wrong();
      final before = _position;
      _position = next;
      _lastMove = move;
      _status = _Status.wrong;
      _controller.updatePosition(_gameData());
      setState(() {});
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        _position = before;
        _lastMove = _puzzle.lastMove != null && _step == 0
            ? NormalMove.fromUci(_puzzle.lastMove!)
            : _lastMove;
        _status = _Status.playing;
        _controller.updatePosition(_gameData());
        setState(() {});
      });
      return;
    }
    final captured = _position.board.pieceAt(move.to) != null;
    _position = next;
    _lastMove = move;
    _step++;
    if (_step >= _puzzle.moves.length || next.isCheckmate) {
      AppFeedback.instance.win();
      _status = _Status.solved;
      ProgressStore.instance.markPuzzleSolved(_puzzle.id);
      _controller.updatePosition(_gameData());
      setState(() {});
      return;
    }
    AppFeedback.instance.move(capture: captured);
    // Rakip cevabı
    _status = _Status.opponentMoving;
    _hintLevel = 0;
    _controller.updatePosition(_gameData());
    setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (!mounted) return;
      final reply = _expected;
      AppFeedback.instance.move(
        capture: _position.board.pieceAt(reply.to) != null,
      );
      _position = _position.playUnchecked(reply);
      _lastMove = reply;
      _step++;
      _status = _Status.playing;
      _controller.updatePosition(_gameData());
      setState(() {});
    });
  }

  static bool _sameMove(Move a, Move b) {
    if (a is NormalMove && b is NormalMove) {
      return a.from == b.from &&
          a.to == b.to &&
          (a.promotion ?? Role.queen) == (b.promotion ?? Role.queen);
    }
    return a == b;
  }

  void _hint() {
    setState(() {
      _hintLevel = (_hintLevel + 1).clamp(0, 2);
      _usedHint = true;
    });
  }

  void _next() {
    // Çözülmüşleri atla (seviye sırası farklı kategorilerden önceden çözülenleri de içerir).
    final nextIndex = widget.puzzles.indexWhere(
      (p) => !ProgressStore.instance.isPuzzleSolved(p.id),
      widget.index + 1,
    );
    if (nextIndex < 0) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PuzzleScreen(puzzles: widget.puzzles, index: nextIndex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final side = _playerSide == Side.white ? t.white : t.black;
    final total = _puzzle.playerMoveCount;
    final playerMoveNo = _step ~/ 2 + 1;
    final (text, tone) = switch (_status) {
      _Status.playing => (
        total == 1
            ? t.puzzleMateIn1Prompt(side)
            : t.puzzleMateInNPrompt(side, total, playerMoveNo),
        BannerTone.neutral,
      ),
      _Status.opponentMoving => (t.opponentReplying, BannerTone.info),
      _Status.wrong => (t.notThisOne, BannerTone.error),
      _Status.solved => (
        _usedHint ? t.solvedWithHint : t.solvedGreat,
        BannerTone.success,
      ),
    };
    final hasNext = widget.index + 1 < widget.puzzles.length;
    final starter = starterTitle(t, _puzzle.id);
    final hint = starterHint(t, _puzzle.id);
    final title =
        starter ??
        '${t.puzzleN(widget.index + 1)}${_puzzle.rating != null ? ' · ${_puzzle.rating}' : ''}';

    final shapes = <Shape>{};
    if (_status == _Status.playing && _hintLevel > 0) {
      final e = _expected;
      if (e is NormalMove) {
        shapes.add(
          Circle(color: AppColors.gold.withValues(alpha: 0.9), orig: e.from),
        );
        if (_hintLevel > 1) {
          shapes.add(
            Arrow(
              color: AppColors.lessons.withValues(alpha: 0.85),
              orig: e.from,
              dest: e.to,
            ),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: StatusBanner(text: text, tone: tone),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  // Tahta üstte; ipucu ve düğme hemen altında, kalan boşluk bölüm ilerlemesine.
                  final size = min(c.maxWidth - 32, c.maxHeight - 150);
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Chessboard(
                          controller: _controller,
                          size: size,
                          settings: SettingsStore.instance.boardSettings,
                          orientation: _playerSide,
                          onMove: _onMove,
                          shapes: shapes,
                        ),
                      ),
                      if (hint != null &&
                          _hintLevel > 0 &&
                          _status != _Status.solved)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                          child: Text(
                            '💡 $hint',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: _status == _Status.solved
                            ? FilledButton.icon(
                                onPressed: _next,
                                icon: Icon(
                                  hasNext
                                      ? Icons.arrow_forward_rounded
                                      : Icons.done_all_rounded,
                                ),
                                label: Text(
                                  hasNext ? t.nextPuzzle : t.doneGoBack,
                                ),
                              )
                            : OutlinedButton.icon(
                                onPressed:
                                    _hintLevel >= 2 ||
                                        _status != _Status.playing
                                    ? null
                                    : _hint,
                                icon: const Icon(
                                  Icons.lightbulb_outline_rounded,
                                ),
                                label: Text(switch (_hintLevel) {
                                  0 => t.hintWhichPiece,
                                  1 => t.hintWhere,
                                  _ => t.hintShown,
                                }),
                              ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value:
                                      (widget.index + 1) /
                                      widget.puzzles.length,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceContainer,
                                  color: AppColors.puzzles,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${widget.index + 1} / ${widget.puzzles.length}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
