import 'dart:math';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../core/feedback.dart';
import '../../core/progress_store.dart';
import '../../core/settings_store.dart';
import '../../core/theme.dart';
import '../../core/widgets/status_banner.dart';
import 'lessons.dart';
import '../../l10n/l10n.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lesson});
  final Lesson lesson;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int _stepIndex = 0;
  bool _taskDone = false;
  String? _feedback;
  bool _feedbackOk = false;

  LessonStep get _step => widget.lesson.steps[_stepIndex];
  bool get _isLast => _stepIndex == widget.lesson.steps.length - 1;
  bool get _canContinue => _step.task == null || _taskDone;

  void _next() {
    if (_isLast) {
      ProgressStore.instance.markLessonDone(widget.lesson.id);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _stepIndex++;
      _taskDone = false;
      _feedback = null;
    });
  }

  void _onTaskResult(bool ok, String message) {
    setState(() {
      _taskDone = ok;
      _feedbackOk = ok;
      _feedback = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final settings = SettingsStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.lesson.emoji} ${widget.lesson.title}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_stepIndex + 1) / widget.lesson.steps.length,
            minHeight: 6,
            color: AppColors.lessons,
            backgroundColor: AppColors.outline,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2, right: 12),
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.navyLight,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_stepIndex + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyDark,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      step.text,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontSize: 17),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final size = min(c.maxWidth, c.maxHeight);
                      final task = step.task;
                      if (task == null) {
                        return StaticChessboard(
                          size: size,
                          orientation: Side.white,
                          fen: step.fen,
                          settings: settings.staticBoardSettings,
                        );
                      }
                      return _TaskBoard(
                        key: ValueKey('${widget.lesson.id}-$_stepIndex'),
                        size: size,
                        fen: step.fen,
                        task: task,
                        settings: settings.boardSettings,
                        onResult: _onTaskResult,
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: StatusBanner(
                text:
                    _feedback ??
                    (step.task != null ? context.t.taskMoveHint : context.t.readyContinue),
                tone: _feedback == null
                    ? BannerTone.neutral
                    : (_feedbackOk ? BannerTone.success : BannerTone.error),
                icon: _feedback == null && step.task == null
                    ? Icons.menu_book_rounded
                    : null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: FilledButton.icon(
                onPressed: _canContinue ? _next : null,
                icon: Icon(
                  _isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                ),
                label: Text(_isLast ? context.t.finishLesson : context.t.continueBtn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tek bir görevi olan etkileşimli tahta: doğru hamle yapılınca kilitlenir,
/// yanlış hamlede konumu geri alır. Hedef kareler halka ile işaretlenir.
class _TaskBoard extends StatefulWidget {
  const _TaskBoard({
    super.key,
    required this.size,
    required this.fen,
    required this.task,
    required this.settings,
    required this.onResult,
  });

  final double size;
  final String fen;
  final MoveTask task;
  final ChessboardSettings settings;
  final void Function(bool ok, String message) onResult;

  @override
  State<_TaskBoard> createState() => _TaskBoardState();
}

class _TaskBoardState extends State<_TaskBoard> {
  late Position _position;
  late ChessboardController _controller;
  bool _done = false;
  Move? _lastMove;

  @override
  void initState() {
    super.initState();
    _position = Chess.fromSetup(Setup.parseFen(widget.fen));
    _controller = ChessboardController(game: _gameData());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  GameData _gameData() {
    final from = Square.fromName(widget.task.from);
    final legal = makeLegalMoves(_position);
    final only = {if (legal.containsKey(from)) from: legal[from]!};
    return GameData(
      fen: _position.fen,
      lastMove: _lastMove,
      playerSide: _done
          ? PlayerSide.none
          : (_position.turn == Side.white
                ? PlayerSide.white
                : PlayerSide.black),
      sideToMove: _position.turn,
      kingSquareInCheck: _position.isCheck
          ? _position.board.kingOf(_position.turn)
          : null,
      validMoves: only,
    );
  }

  void _onMove(Move move, {bool? viaDragAndDrop}) {
    if (_done) return;
    final ok = widget.task.targets.contains(move.to.name);
    if (ok) {
      AppFeedback.instance.correct();
      _position = _position.playUnchecked(move);
      _lastMove = move;
      _done = true;
      widget.onResult(true, widget.task.success);
    } else {
      AppFeedback.instance.wrong();
      widget.onResult(false, context.t.wrongTarget);
    }
    _controller.updatePosition(_gameData(), animate: ok);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final from = Square.fromName(widget.task.from);
    final shapes = <Shape>{
      if (!_done)
        Circle(color: AppColors.gold.withValues(alpha: 0.9), orig: from),
      if (!_done)
        for (final t in widget.task.targets)
          if (t != 'h1' && t != 'h8') // rok hedefinde kale karesini işaretleme
            Arrow(
              color: AppColors.lessons.withValues(alpha: 0.8),
              orig: from,
              dest: Square.fromName(t),
            ),
    };
    return Chessboard(
      controller: _controller,
      size: widget.size,
      settings: widget.settings,
      orientation: Side.white,
      onMove: _onMove,
      shapes: shapes,
    );
  }
}
