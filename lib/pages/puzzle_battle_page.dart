// lib/pages/puzzle_battle_page.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/match.dart';
import '../services/socket_service.dart';
import '../services/puzzle_game_service.dart';
import '../services/puzzle_generate_service.dart';
import '../models/puzzle_piece.dart';
import '../services/auth_service.dart';

// 经典模式下方块的高亮提示画笔
class PuzzlePieceHighlightPainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Path shapePath;
  final Rect bounds;

  PuzzlePieceHighlightPainter({
    required this.image,
    required this.scale,
    required this.shapePath,
    required this.bounds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..color = Colors.green.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    final borderPaint = Paint()
      ..color = Colors.green.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final fillPaint = Paint()
      ..color = Colors.green.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    final scaleX = size.width / bounds.width;
    final scaleY = size.height / bounds.height;
    final matrix = Matrix4.identity()..scale(scaleX, scaleY);
    final finalPath = shapePath.transform(matrix.storage);
    canvas.drawPath(finalPath, fillPaint);
    canvas.drawPath(finalPath, glowPaint);
    canvas.drawPath(finalPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PuzzlePieceHighlightPainter oldDelegate) => true;
}


class PuzzleBattlePage extends StatefulWidget {
  final Match match;
  const PuzzleBattlePage({super.key, required this.match});

  @override
  State<PuzzleBattlePage> createState() => _PuzzleBattlePageState();
}

class _PuzzleBattlePageState extends State<PuzzleBattlePage> {
  // --- 核心服务 ---
  final SocketService _socketService = SocketService();
  final AuthService _authService = AuthService();
  late final PuzzleGameService _gameService;
  late final PuzzleGenerateService _generator;

  // --- 状态变量 ---
  late Future<void> _initFuture;
  ui.Image? _targetImage;
  double _opponentProgress = 0.0;
  String _statusMessage = "正在准备战场...";
  bool _isMyGameFinished = false;
  final Stopwatch _stopwatch = Stopwatch();

  // --- UI & 拖拽交互状态 ---
  double _scale = 1.0;
  final GlobalKey _puzzleAreaKey = GlobalKey();
  PuzzlePiece? _currentClassicDraggingPiece; // 【修正】变量名修正
  bool _shouldHighlightTarget = false;

  // 大师模式交互状态
  final TransformationController _transformationController = TransformationController();
  int? _draggedPieceId;
  Offset _lastFocalPoint = Offset.zero;

  // --- Stream Subscriptions ---
  late StreamSubscription _opponentProgressSubscription;
  late StreamSubscription _matchOverSubscription;
  StreamSubscription? _gameStatusSubscription;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _gameService = PuzzleGameService();
    _generator = PuzzleGenerateService();

    if (widget.match.difficulty == 'master') {
      _initFuture = _initializeMasterBattle();
      _progressSubscription = _gameService.masterPiecesStream.listen((_) => _onMyProgressUpdated());
    } else {
      _initFuture = _initializeClassicBattle();
      // _progressSubscription = _gameService.placedPiecesStream.listen((_) => _onMyProgressUpdated());
    }

    _opponentProgressSubscription = _socketService.onOpponentProgress.listen((progress) {
      if (mounted) setState(() => _opponentProgress = progress / 100.0);
    });
    _matchOverSubscription = _socketService.onMatchOver.listen(_showGameResultDialog);
    _gameStatusSubscription = _gameService.statusStream.listen((status) {
      if (status == GameStatus.completed && !_isMyGameFinished) {
        _onMyGameCompleted();
      }
    });
  }

  @override
  void dispose() {
    _opponentProgressSubscription.cancel();
    _matchOverSubscription.cancel();
    _gameStatusSubscription?.cancel();
    _progressSubscription?.cancel();
    _transformationController.dispose();
    _gameService.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  // --- 初始化逻辑 ---

  Future<void> _initializeClassicBattle() async {
    try {
      setState(() => _statusMessage = "正在生成经典拼图...");
      final difficultyMap = {'easy': 1, 'medium': 2, 'hard': 3};
      final difficulty = difficultyMap[widget.match.difficulty] ?? 1;
      final pieces = await _generator.generatePuzzle(widget.match.imageSource, difficulty);
      _targetImage = _generator.lastLoadedImage;

      // ▼▼▼ 【修正】调用正确的方法名 initGame ▼▼▼
      await _gameService.initGame(pieces, difficulty);

      _gameService.startGame();
      _stopwatch.start();
      if(mounted) setState(() => _statusMessage = "对战开始！");
    } catch (e) {
      if (mounted) setState(() => _statusMessage = "游戏初始化失败: $e");
    }
  }

  Future<void> _initializeMasterBattle() async {
    try {
      setState(() => _statusMessage = "正在生成大师拼图...");
      final pieces = await _generator.generatePuzzle(widget.match.imageSource, 3);
      _targetImage = _generator.lastLoadedImage;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final RenderBox? board = _puzzleAreaKey.currentContext?.findRenderObject() as RenderBox?;
        if (board != null) {
          _gameService.initMasterGame(pieces, board.size);
          _gameService.startGame();
          _stopwatch.start();
          if(mounted) setState(() => _statusMessage = "大师对战开始！");
        }
      });
    } catch (e) {
      if (mounted) setState(() => _statusMessage = "游戏初始化失败: $e");
    }
  }

  // --- 进度与完成逻辑 ---

  void _onMyProgressUpdated() {
    // if (_isMyGameFinished) return;
    double myProgress = 0.0;

    if (widget.match.difficulty == 'master') {
      if (_gameService.masterPieces.isNotEmpty) {
        final groupCounts = <int, int>{};
        for (var p in _gameService.masterPieces) {
          groupCounts[p.group] = (groupCounts[p.group] ?? 0) + 1;
        }
        final maxGroupSize = groupCounts.values.fold(0, (max, current) => current > max ? current : max);
        myProgress = maxGroupSize / _gameService.masterPieces.length;
      }
    } else {
      // ▼▼▼ 【修正】使用正确的列表长度获取总块数 ▼▼▼
      final totalPieces = _gameService.placedPieces.length;
      if (totalPieces > 0) {
        final placedCount = _gameService.placedPieces.where((p) => p != null).length;
        myProgress = placedCount / totalPieces;
      }
    }
    _socketService.updateProgress(widget.match.id, myProgress * 100);
  }

  void _onMyGameCompleted() {
    _isMyGameFinished = true;
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    if (mounted) {
      setState(() { _statusMessage = "你已完成！用时: ${(elapsedMs / 1000).toStringAsFixed(2)}s. 等待对手..."; });
    }
    _socketService.playerFinished(widget.match.id, elapsedMs);
  }

  void _showGameResultDialog(Map<String, dynamic> resultData) {
    if (!mounted) return;
    final result = resultData['result'];
    final winnerId = result['winner_id'];
    final myId = _authService.currentUser?['id'];
    String title;
    Color titleColor;
    if (myId == null) {
      title = "比赛结束"; titleColor = Colors.grey;
    } else if (winnerId == null) {
      title = "平局！"; titleColor = Colors.blue;
    } else if (winnerId == myId) {
      title = "🎉 你赢了！"; titleColor = Colors.green;
    } else {
      title = "再接再厉！"; titleColor = Colors.orange;
    }
    showDialog( context: context, barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(title, style: TextStyle(color: titleColor)),
          content: const Text("比赛已结束，返回大厅查看结果。"),
          actions: [
            TextButton(
              onPressed: () { Navigator.of(dialogContext).pop(); Navigator.of(context).pop(); },
              child: const Text("返回"),
            )
          ],
        )
    );
  }

  // --- UI 构建方法 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('对战中 - ${widget.match.difficultyText}')),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || (_targetImage == null && widget.match.difficulty != 'master')) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_statusMessage)]));
          }
          if (snapshot.hasError) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error, color: Colors.red), const SizedBox(height: 16), Text('发生错误: ${snapshot.error}')]));
          }

          return Column(
            children: [
              _buildOpponentProgress(),
              Expanded(
                child: widget.match.difficulty == 'master'
                    ? _buildMasterModeUI()
                    : _buildClassicModeUI(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOpponentProgress() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("对手进度", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _opponentProgress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(5),
            color: Colors.redAccent,
            backgroundColor: Colors.red.shade100,
          ),
        ],
      ),
    );
  }

  // --- 经典模式 UI ---
  Widget _buildClassicModeUI() {
    final size = MediaQuery.of(context).size;
    return Column(
      children: [
        SizedBox(
          height: min(size.height * 0.6, size.width),
          child: _buildPuzzlePlacementArea(),
        ),
        const Divider(height: 4, thickness: 4, color: Colors.blue),
        Expanded(child: _buildAvailablePiecesArea()),
      ],
    );
  }

  Widget _buildPuzzlePlacementArea() {
    if (_targetImage == null) return const Center(child: Text("正在加载图片..."));
    final double targetWidth = _targetImage!.width.toDouble();
    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double availableHeight = MediaQuery.of(context).size.height * 0.55;
    final double squareSize = min(availableWidth, availableHeight);
    _scale = squareSize / targetWidth;

    return Center(
      child: Container(
        key: _puzzleAreaKey,
        width: squareSize,
        height: squareSize,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Stack(
          children: [
            // ▼▼▼ BUG修复：移除 StreamBuilder，改用与单人模式相同的直接构建方式 ▼▼▼
            // 这样可以确保每次 setState 都能正确刷新UI
            ...List.generate(_gameService.placedPieces.length, (i) {
              if (_gameService.placedPieces[i] == null) {
                return const SizedBox.shrink();
              }
              final piece = _gameService.placedPieces[i]!;
              return Positioned(
                left: piece.position.dx * _scale - (piece.pivot.dx * _scale),
                top: piece.position.dy * _scale - (piece.pivot.dy * _scale),
                child: RawImage(
                  image: piece.image,
                  width: (piece.image.width.toDouble()) * _scale,
                  height: (piece.image.height.toDouble()) * _scale,
                ),
              );
            }),
            // ▲▲▲ 修复结束 ▲▲▲

            if (_shouldHighlightTarget && _currentClassicDraggingPiece != null)
              Positioned(
                left: _currentClassicDraggingPiece!.position.dx * _scale - (_currentClassicDraggingPiece!.pivot.dx * _scale),
                top: _currentClassicDraggingPiece!.position.dy * _scale - (_currentClassicDraggingPiece!.pivot.dy * _scale),
                child: CustomPaint(
                  size: Size(
                    _currentClassicDraggingPiece!.image.width.toDouble() * _scale,
                    _currentClassicDraggingPiece!.image.height.toDouble() * _scale,
                  ),
                  painter: PuzzlePieceHighlightPainter(
                    image: _currentClassicDraggingPiece!.image,
                    scale: _scale,
                    shapePath: _currentClassicDraggingPiece!.shapePath,
                    bounds: _currentClassicDraggingPiece!.bounds,
                  ),
                ),
              ),

            Positioned.fill(
              child: DragTarget<int>(
                builder: (context, _, __) => Container(color: Colors.transparent),
                onWillAccept: (nodeId) => nodeId != null && !_isMyGameFinished,
                onAccept: (nodeId) {
                  final pieceIndex = _gameService.availablePieces.indexWhere((p) => p.nodeId == nodeId);
                  if (pieceIndex != -1 && _currentClassicDraggingPiece != null) {
                    final targetPosition = _currentClassicDraggingPiece!.nodeId;
                    if (_shouldHighlightTarget && _gameService.placedPieces[targetPosition] == null) {
                      _gameService.placePiece(pieceIndex, targetPosition);
                      _onMyProgressUpdated();
                    }
                  }
                  // ▼▼▼ 关键：这里的 setState 会触发整个 build 方法，从而让上面的 for 循环重新绘制 ▼▼▼
                  setState(() {
                    _currentClassicDraggingPiece = null;
                    _shouldHighlightTarget = false;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailablePiecesArea() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8.0),
      child: StreamBuilder<List<PuzzlePiece>>(
        stream: _gameService.availablePiecesStream,
        initialData: _gameService.availablePieces,
        builder: (context, snapshot) {
          final pieces = snapshot.data ?? [];
          if (pieces.isEmpty && !_isMyGameFinished) {
            return Center(child: Text(_statusMessage));
          }
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: pieces.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Center(
                  child: _buildDraggablePuzzlePiece(pieces[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDraggablePuzzlePiece(PuzzlePiece piece) {
    return Draggable<int>(
      data: piece.nodeId,
      feedback: Transform.scale(
        scale: 1.1,
        child: SizedBox(width: 50, height: 50, child: RawImage(image: piece.image)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: SizedBox(width: 50, height: 50, child: RawImage(image: piece.image)),
      ),
      onDragStarted: () => setState(() {
        _currentClassicDraggingPiece = piece;
        _shouldHighlightTarget = false;
      }),
      onDragUpdate: (details) {
        if (_currentClassicDraggingPiece == null) return;
        final RenderBox? puzzleAreaBox = _puzzleAreaKey.currentContext?.findRenderObject() as RenderBox?;
        if (puzzleAreaBox == null) return;
        final localPosition = puzzleAreaBox.globalToLocal(details.globalPosition);
        final targetCenter = Offset(_currentClassicDraggingPiece!.position.dx * _scale, _currentClassicDraggingPiece!.position.dy * _scale);
        final tolerance = (_currentClassicDraggingPiece!.image.width * _scale) / 2;
        final distance = (localPosition - targetCenter).distance;
        final shouldBeHighlighted = distance < tolerance;
        if (shouldBeHighlighted != _shouldHighlightTarget) {
          setState(() => _shouldHighlightTarget = shouldBeHighlighted);
        }
      },
      onDragEnd: (details) => setState(() {
        _currentClassicDraggingPiece = null;
        _shouldHighlightTarget = false;
      }),
      child: SizedBox(width: 50, height: 50, child: RawImage(image: piece.image)),
    );
  }


  // --- 大师模式 UI ---
  Widget _buildMasterModeUI() {
    return Container(
      key: _puzzleAreaKey,
      color: Colors.blueGrey.shade900,
      child: GestureDetector(
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.1,
          maxScale: 4.0,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(double.infinity),
          child: StreamBuilder<List<MasterPieceState>>(
            stream: _gameService.masterPiecesStream,
            initialData: _gameService.masterPieces,
            builder: (context, snapshot) {
              final pieces = snapshot.data ?? [];
              final boardSize = _puzzleAreaKey.currentContext?.size ?? const Size(1000, 1000);
              return SizedBox(
                width: boardSize.width,
                height: boardSize.height,
                child: Stack(
                  children: pieces.map((state) {
                    return Positioned(
                      left: state.position.dx,
                      top: state.position.dy,
                      child: Transform.rotate(
                        angle: state.rotation,
                        child: Transform.scale(
                          scale: state.scale,
                          child: RawImage(
                            image: state.piece.image,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- 大师模式手势处理 ---
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.focalPoint;
    final tapPosition = _transformationController.toScene(details.localFocalPoint);
    int? topPieceId;
    for (var state in _gameService.masterPieces.reversed) {
      final pieceRect = Rect.fromCenter(center: state.position, width: state.piece.pieceSize * state.scale, height: state.piece.pieceSize * state.scale);
      if (pieceRect.contains(tapPosition)) {
        topPieceId = state.piece.nodeId;
        break;
      }
    }
    _draggedPieceId = topPieceId;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_draggedPieceId == null) return;
    final focalPoint = details.focalPoint;
    final focalPointDelta = focalPoint - _lastFocalPoint;
    _lastFocalPoint = focalPoint;
    final draggedState = _gameService.masterPieces.firstWhere((p) => p.piece.nodeId == _draggedPieceId);
    final groupToMove = draggedState.group;
    for (var state in _gameService.masterPieces) {
      if (state.group == groupToMove) {
        state.position += focalPointDelta / _transformationController.value.getMaxScaleOnAxis();
        if (details.scale != 1.0 || details.rotation != 0.0) {
          state.rotation += details.rotation;
          state.scale *= details.scale;
        }
      }
    }
    _gameService.updateMasterPieceTransform(draggedState.piece.nodeId, draggedState.position, draggedState.scale, draggedState.rotation);
    _gameService.checkForSnapping(_draggedPieceId!);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_draggedPieceId != null) {
      if (_gameService.snapTarget != null) {
        _gameService.snapPieces();
      }
      _draggedPieceId = null;
    }
  }
}