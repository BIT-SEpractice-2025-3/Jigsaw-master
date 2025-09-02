import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/models/puzzle_piece.dart';
import '/services/puzzle_game_service.dart';
import '/services/puzzle_generate_service.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

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

  // int? _selectedPieceId; // 移除这一行
  int? _selectedGroupId; // 添加这一行
  bool _gameInitialized = false;
  SnapTarget? _snapTarget;
  Offset? _lastFocalPoint;
  void _rotateGroup(int groupId, double rotationDelta) {
    final groupPieces = _gameService.masterPieces.where((p) => p.group == groupId).toList();
    if (groupPieces.length <= 1) {
      // 如果组里只有一个块，直接旋转即可
      if (groupPieces.isNotEmpty) {
        groupPieces.first.rotation += rotationDelta;
      }
      return;
    }

    // 1. 计算组的中心点 (基于块的 pivot 点的平均值)
    Offset groupCenter = Offset.zero;
    for (var p in groupPieces) {
      groupCenter += p.position;
    }
    groupCenter = groupCenter / groupPieces.length.toDouble();

    // 2. 对组内的每个块应用旋转
    for (var p in groupPieces) {
      // a. 获取块 pivot 相对于组中心的向量
      final relativePos = p.position - groupCenter;

      // b. 旋转该向量
      final rotatedRelativePos = Offset(
        relativePos.dx * cos(rotationDelta) - relativePos.dy * sin(rotationDelta),
        relativePos.dx * sin(rotationDelta) + relativePos.dy * cos(rotationDelta),
      );

      // c. 计算块的新绝对位置 (pivot 的新位置)
      p.position = groupCenter + rotatedRelativePos;

      // d. 更新块自身的旋转角度
      p.rotation += rotationDelta;
    }
  }
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
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _initializeGame(boardSize);
                  });
                }

                // 用 GestureDetector 包裹画板以处理取消选择的逻辑
                return GestureDetector(
                  onTap: () {
                    // 当点击背景时取消选择
                    if (_selectedGroupId != null) {
                      setState(() {
                        _selectedGroupId = null;
                      });
                    }
                  },
                  child: Container(
                    width: boardSize.width,
                    height: boardSize.height,
                    color: Colors.grey.shade300,
                    child: Stack(
                      children: [
                        // 渲染所有拼图块
                        if (_gameInitialized)
                          ..._gameService.masterPieces.map((pieceState) {
                            return _buildDraggablePiece(pieceState);
                          }).toList(),

                        // 在所有组件之上渲染控件
                        if (_gameInitialized)
                          _buildGroupControls(),

                        if (!_gameInitialized)
                          const Center(child: CircularProgressIndicator())
                      ],
                    ),
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
    final pieceWidget = CustomPaint(
      painter: _PuzzlePiecePainter(
        piece: piece,
        // 如果拼图块所在的分组是被选中的分组，则该块也为选中状态
        isSelected: _selectedGroupId == pieceState.group,
        snapTarget: _snapTarget,
      ),
      size: piece.bounds.size,
    );

    return Transform(
      transform: Matrix4.identity()
        ..translate(pieceState.position.dx, pieceState.position.dy)
        ..rotateZ(pieceState.rotation)
        ..scale(pieceState.scale)
        ..translate(-piece.pivot.dx, -piece.pivot.dy),
      child: GestureDetector(
        onTap: () {
          setState(() {
            // 当被点击时，选中整个分组
            _selectedGroupId = pieceState.group;
          });
        },
        onScaleStart: (details) {
          // 如果手势在一个拼图块上开始，则选中其所在的分组
          if (_selectedGroupId != pieceState.group) {
            setState(() {
              _selectedGroupId = pieceState.group;
            });
          }
          _lastFocalPoint = details.focalPoint;
        },
        onScaleUpdate: (details) {
          if (_selectedGroupId != pieceState.group) return;
          if (_lastFocalPoint == null) return;

          final focalPointDelta = details.focalPoint - _lastFocalPoint!;
          _lastFocalPoint = details.focalPoint;

          setState(() {
            final groupID = pieceState.group;
            final groupPieces = _gameService.masterPieces.where((p) => p.group == groupID).toList();

            // --- 分组平移 ---
            for (var p in groupPieces) {
              p.position += focalPointDelta;
            }

            // --- 分组旋转 ---
            if (details.rotation != 0.0) {
              final rotationDelta = details.rotation * 0.5;
              _rotateGroup(groupID, rotationDelta);
            }

            _gameService.checkForSnapping(pieceState.piece.nodeId);
          });
        },
        onScaleEnd: (details) {
          _lastFocalPoint = null;
          if (_selectedGroupId != pieceState.group) return;

          // 优先处理拼图块之间的吸附
          if (_snapTarget != null && _snapTarget!.draggedPieceId == pieceState.piece.nodeId) {
            setState(() {
              _gameService.snapPieces();
            });
          } else {
            // 如果没有发生吸附，则执行角度对齐
            setState(() {
              final groupID = pieceState.group;
              final currentRotation = pieceState.rotation;
              const baseAngle = pi / 4; // 45度

              // 计算最接近的45度倍数角度
              final snappedRotation = (currentRotation / baseAngle).round() * baseAngle;

              // 计算需要修正的角度差值
              final rotationDelta = snappedRotation - currentRotation;

              // 如果角度差很小，则无需旋转，避免不必要的重绘
              if (rotationDelta.abs() > 0.001) {
                _rotateGroup(groupID, rotationDelta);
              }
            });
          }
        },
        // 子组件现在只有拼图块本身，不再包含旋转控件
        child: pieceWidget,
      ),
    );
  }
// 在 _PuzzleMasterPageState 类中添加这个新方法
// 在 _PuzzleMasterPageState 类中，用下面的代码替换整个 _buildGroupControls 方法

  Widget _buildGroupControls() {
    if (_selectedGroupId == null) {
      return const SizedBox.shrink();
    }

    final groupPieces = _gameService.masterPieces.where((p) => p.group == _selectedGroupId!).toList();
    if (groupPieces.isEmpty) {
      return const SizedBox.shrink();
    }

    // 步骤 1: 计算整个分组在屏幕上的精确视觉边界框 (这部分逻辑是正确的，保持不变)
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (var pieceState in groupPieces) {
      final piece = pieceState.piece;
      final transform = Matrix4.identity()
        ..translate(pieceState.position.dx, pieceState.position.dy)
        ..rotateZ(pieceState.rotation)
        ..scale(pieceState.scale)
        ..translate(-piece.pivot.dx, -piece.pivot.dy);

      final corners = [
        Offset(piece.bounds.left, piece.bounds.top),
        Offset(piece.bounds.right, piece.bounds.top),
        Offset(piece.bounds.right, piece.bounds.bottom),
        Offset(piece.bounds.left, piece.bounds.bottom),
      ];

      for (var corner in corners) {
        final transformedVector = transform.transform3(Vector3(corner.dx, corner.dy, 0));
        minX = min(minX, transformedVector.x);
        minY = min(minY, transformedVector.y);
        maxX = max(maxX, transformedVector.x);
        maxY = max(maxY, transformedVector.y);
      }
    }

    // 得到最终的视觉边界矩形
    final groupBounds = Rect.fromLTRB(minX, minY, maxX, maxY);

    // --- 步骤 2: 简化定位逻辑 ---
    // 直接使用边界框的角点来定位按钮，不再计算半径和角度

    const iconSize = 32.0;
    const touchTargetSize = 48.0;
    const offset = touchTargetSize / 2; // 偏移量，使得按钮的中心点对齐到角点

    return Stack(
      fit: StackFit.expand,
      children: [
        // 左上角旋转按钮
        Positioned(
          // 直接定位到边界框的左上角
          left: groupBounds.left - offset,
          top: groupBounds.top - offset,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _rotateGroup(_selectedGroupId!, -pi / 4); // 逆时针旋转45度
              });
              _gameService.checkForSnapping(groupPieces.first.piece.nodeId);
            },
            child: Container(
              width: touchTargetSize,
              height: touchTargetSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.rotate_left, color: Colors.blue, size: iconSize),
            ),
          ),
        ),

        // 右下角旋转按钮
        Positioned(
          // 直接定位到边界框的右下角
          left: groupBounds.right - offset,
          top: groupBounds.bottom - offset,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _rotateGroup(_selectedGroupId!, pi / 4); // 顺时针旋转45度
              });
              _gameService.checkForSnapping(groupPieces.first.piece.nodeId);
            },
            child: Container(
              width: touchTargetSize,
              height: touchTargetSize,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.rotate_right, color: Colors.blue, size: iconSize),
            ),
          ),
        ),
      ],
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
