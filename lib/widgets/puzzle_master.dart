import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/models/puzzle_piece.dart';
import '/services/puzzle_game_service.dart';
import '/services/puzzle_generate_service.dart';

class PuzzleMasterPage extends StatefulWidget {
  final String imageSource;
  final int difficulty;

  const PuzzleMasterPage({
    Key? key,
    required this.imageSource,
    required this.difficulty,
  }) : super(key: key);

  @override
  _PuzzleMasterPageState createState() => _PuzzleMasterPageState();
}

class _PuzzleMasterPageState extends State<PuzzleMasterPage> {
  final PuzzleGameService _gameService = PuzzleGameService();
  final PuzzleGenerateService _generateService = PuzzleGenerateService();

  int? _selectedPieceId;
  bool _gameInitialized = false;
  SnapTarget? _snapTarget;
  Offset? _lastFocalPoint;

  @override
  void initState() {
    super.initState();
    // 监听吸附事件以更新UI
    _gameService.snapStream.listen((snapTarget) {
      if (mounted && _snapTarget != snapTarget) {
        setState(() {
          _snapTarget = snapTarget;
        });
      }
    });
  }

  Future<void> _initializeGame(ui.Size boardSize) async {
    if (_gameInitialized) return;
    final pieces = await _generateService.generatePuzzle(widget.imageSource, widget.difficulty);
    _gameService.initMasterGame(pieces, boardSize);
    if (mounted) {
      setState(() {
        _gameInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('大师模式')),
      body: Column(
        children: [
          // 预览图区域
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: _generateService.lastLoadedImage != null
                      ? RawImage(
                          image: _generateService.lastLoadedImage!,
                          fit: BoxFit.cover,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(width: 16),
                const Text("预览图", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          // 拼图区域
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = ui.Size(constraints.maxWidth, constraints.maxHeight);

                if (!_gameInitialized) {
                  // Use a post-frame callback to avoid calling setState during build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _initializeGame(boardSize);
                  });
                }

                return Container(
                  width: boardSize.width,
                  height: boardSize.height,
                  color: Colors.grey.shade300,
                  child: Stack(
                    // Only build the stack if the game is initialized
                    children: _gameInitialized
                        ? _gameService.masterPieces.map((pieceState) {
                            return _buildDraggablePiece(pieceState);
                          }).toList()
                        : [const Center(child: CircularProgressIndicator())],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggablePiece(MasterPieceState pieceState) {
    final piece = pieceState.piece;
    // 修正：使用 piece.bounds.size 作为 CustomPaint 的尺寸
    final pieceWidget = CustomPaint(
      painter: _PuzzlePiecePainter(
        piece: piece,
        isSelected: _selectedPieceId == piece.nodeId,
        snapTarget: _snapTarget,
      ),
      size: piece.bounds.size,
    );

    // 将拼图块和控制器包裹在Stack中
    final pieceWithControls = Stack(
      clipBehavior: Clip.none, // 允许箭头绘制在边界之外
      children: [
        pieceWidget,
        // 如果拼图块被选中，则显示旋转控制器
        if (_selectedPieceId == pieceState.piece.nodeId) ...[
          // 左上角：逆时针旋转
          Positioned(
            left: -12,
            top: -12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 逆时针旋转45度
                  pieceState.rotation -= pi / 4;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rotate_left, color: Colors.blue, size: 80),
              ),
            ),
          ),
          // 右下角：顺时针旋转
          Positioned(
            right: -12,
            bottom: -12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 顺时针旋转45度
                  pieceState.rotation += pi / 4;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rotate_right, color: Colors.blue, size: 80),
              ),
            ),
          ),
        ],
      ],
    );

    return Transform(
      transform: Matrix4.identity()
        // 4. 将变换后的拼图块移动到其在画布上的最终位置
        ..translate(pieceState.position.dx, pieceState.position.dy)
        // 3. 围绕原点（现在是pivot点）进行旋转
        ..rotateZ(pieceState.rotation)
        // 2. 围绕原点（现在是pivot点）进行缩放
        ..scale(pieceState.scale)
        // 1. 将拼图块平移，使其物理左上角（pivot）与画布原点对齐
        ..translate(-piece.pivot.dx, -piece.pivot.dy),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPieceId = pieceState.piece.nodeId;
          });
        },
        onScaleStart: (details) {
          // 当手势开始时，如果该拼图块未被选中，则选中它
          if (_selectedPieceId != pieceState.piece.nodeId) {
            setState(() {
              _selectedPieceId = pieceState.piece.nodeId;
            });
          }
          _lastFocalPoint = details.focalPoint;
        },
        // 使用 onScaleUpdate 统一处理平移、缩放和旋转，以避免手势冲突
        onScaleUpdate: (details) {
          // 只对选中的拼图块进行变换
          if (_selectedPieceId != pieceState.piece.nodeId) return;
          if (_lastFocalPoint == null) return;

          final focalPointDelta = details.focalPoint - _lastFocalPoint!;
          _lastFocalPoint = details.focalPoint;

          setState(() {
            final groupID = pieceState.group;
            final groupPieces = _gameService.masterPieces.where((p) => p.group == groupID).toList();

            // --- 组变换 ---
            // 1. 平移: 移动组内的所有拼图块
            for (var p in groupPieces) {
              p.position += focalPointDelta;
            }

            // 2. 旋转: 将组作为一个刚体进行旋转
            if (details.rotation != 0.0) {
              // a. 计算组的中心点 (基于 pivot 点的平均值)
              Offset groupCenter = Offset.zero;
              for (var p in groupPieces) {
                groupCenter += p.position;
              }
              groupCenter = groupCenter / groupPieces.length.toDouble();

              final rotationDelta = details.rotation * 0.5; // 恢复旋转灵敏度并修正方向

              for (var p in groupPieces) {
                // b. 获取块 pivot 相对于组中心的向量
                final relativePos = p.position - groupCenter;

                // c. 旋转该向量
                final rotatedRelativePos = Offset(
                  relativePos.dx * cos(rotationDelta) - relativePos.dy * sin(rotationDelta),
                  relativePos.dx * sin(rotationDelta) + relativePos.dy * cos(rotationDelta),
                );

                // d. 计算新的绝对位置 (pivot 的新位置)
                p.position = groupCenter + rotatedRelativePos;

                // e. 更新块自身的旋转角度
                p.rotation += rotationDelta;
              }
            }

            // Check for snapping with the currently dragged piece
            _gameService.checkForSnapping(pieceState.piece.nodeId);
          });
        },
        onScaleEnd: (details) {
          _lastFocalPoint = null;
          if (_selectedPieceId != pieceState.piece.nodeId) return;

          // 如果有可吸附的目标，则执行吸附
          if (_snapTarget != null && _snapTarget!.draggedPieceId == pieceState.piece.nodeId) {
            setState(() {
              _gameService.snapPieces();
            });
          } else { // 否则，对齐到45度角
            setState(() {
              // 计算最接近的45度倍数角度
              const baseAngle = pi / 4; // 45 degrees in radians
              final currentRotation = pieceState.rotation;
              final snappedRotation = (currentRotation / baseAngle).round() * baseAngle;
              pieceState.rotation = snappedRotation;
            });
          }
        },
        child: pieceWithControls,
      ),
    );
  }
}

// 自定义 Painter 来绘制拼图块和发光效果
class _PuzzlePiecePainter extends CustomPainter {
  final PuzzlePiece piece;
  final bool isSelected;
  final SnapTarget? snapTarget;

  _PuzzlePiecePainter({required this.piece, this.isSelected = false, this.snapTarget});

  @override
  void paint(Canvas canvas, Size size) {
    // 将画布原点移动到组件中心，因为 shapePath 是居中的
    // canvas.translate(size.width / 2, size.height / 2); // 不再需要，因为基准点是左上角

    final paint = Paint();

    // 绘制选中或可吸附时的发光效果
    bool shouldGlow = isSelected;
    Color glowColor = Colors.yellow;

    // 如果此块是可吸附对的一部分，则发出绿色辉光
    if (snapTarget != null &&
        (snapTarget!.draggedPieceId == piece.nodeId || snapTarget!.targetPieceId == piece.nodeId)) {
      shouldGlow = true;
      glowColor = Colors.greenAccent;
    }

    if (shouldGlow) {
      final glowPaint = Paint()
        ..color = glowColor.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(piece.shapePath, glowPaint);
    }

    // 裁剪并绘制图片
    canvas.save();
    canvas.clipPath(piece.shapePath);
    // 因为 shapePath 和 piece.image 都是基于 piece 的局部坐标
    // 我们需要将图片绘制在正确的位置
    // 修正：传入一个 Offset，而不是两个 double
    canvas.drawImage(
      piece.image,
      Offset.zero, // 图片的左上角与画布的左上角对齐
      paint,
    );
    canvas.restore();

    // 绘制边框
    final borderPaint = Paint()
      ..color = isSelected ? Colors.blue : Colors.black54
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 2.0 : 1.0;
    canvas.drawPath(piece.shapePath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PuzzlePiecePainter oldDelegate) {
    return oldDelegate.piece != piece ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.snapTarget != snapTarget;
  }
}
