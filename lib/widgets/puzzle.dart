//游戏界面
//->主页
//->游戏界面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'dart:math' as Math;
import '../models/puzzle_piece.dart';
import 'home.dart';
import '../services/puzzle_generate_service.dart';
import '../services/puzzle_game_service.dart';

// 修改自定义画笔类，解决发光提示位置问题
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
    // 创建画笔样式
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

    // 修复偏移问题
    // 首先确定拼图形状与边界的关系
    final pathBounds = shapePath.getBounds();

    // 计算形状需要的缩放比例
    final scaleFactorX = size.width / pathBounds.width;
    final scaleFactorY = size.height / pathBounds.height;
    final scaleFactor = Math.min(scaleFactorX, scaleFactorY);

    // 创建变换矩阵
    final matrix = Matrix4.identity()
      ..scale(scaleFactor, scaleFactor);

    // 缩放路径
    final scaledPath = shapePath.transform(matrix.storage);
    final scaledBounds = scaledPath.getBounds();

    // 计算居中偏移量
    final centerOffsetX = (size.width - scaledBounds.width) / 2 - scaledBounds.left;
    final centerOffsetY = (size.height - scaledBounds.height) / 2 - scaledBounds.top;

    // 平移路径到画布中心
    final centeredPath = scaledPath.shift(Offset(centerOffsetX, centerOffsetY));

    // 绘制填充和边框
    canvas.drawPath(centeredPath, fillPaint);
    canvas.drawPath(centeredPath, glowPaint);
    canvas.drawPath(centeredPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant PuzzlePieceHighlightPainter oldDelegate) {
    return true;
  }
}

class PuzzlePage extends StatefulWidget {
  final int difficulty;
  final String? imagePath;

  const PuzzlePage({
    super.key,
    this.difficulty = 1,
    this.imagePath,
  });

  @override
  State<PuzzlePage> createState() => _PuzzlePageState();
}

class _PuzzlePageState extends State<PuzzlePage> {
  late PuzzleGameService _gameService;
  late PuzzleGenerateService _generator;
  late Future<void> _initFuture;
  String? _errorMessage;
  ui.Image? _targetImage; // 存储目标图像

  // 添加成员变量存储缩放比例，以便在多个方法间共享
  double _scale = 1.0;

  // 添加GlobalKey用于获取拼图区域的位置信息
  final GlobalKey _puzzleAreaKey = GlobalKey();

  PuzzlePiece? _currentDraggingPiece;
  int _currentDraggingIndex = -1;
  bool _shouldHighlightTarget = false;
  Offset _lastDragPosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _gameService = PuzzleGameService();
    _generator = PuzzleGenerateService();
    _initFuture = _initializeGame();

    // 监听游戏状态变化
    _gameService.statusStream.listen((status) {
      if (status == GameStatus.completed) {
        _showCompletionDialog();
      }
      setState(() {}); // 刷新UI以反映状态变化
    });
  }

  Future<void> _initializeGame() async {
    try {
      // 使用默认图片或用户选择的图片
      final imageSource = widget.imagePath ?? 'assets/images/default_puzzle.jpg';

      // 生成拼图碎片并获取目标图像
      final pieces = await _generator.generatePuzzle(imageSource, widget.difficulty);

      // 获取缓存的完整图像
      _targetImage = _generator.lastLoadedImage;

      await _gameService.initGame(pieces, widget.difficulty);
      _gameService.startGame();
    } catch (e) {
      setState(() {
        _errorMessage = '初始化游戏失败: $e';
      });
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final score = _gameService.calculateScore();
        final time = _formatTime(_gameService.elapsedSeconds);

        return AlertDialog(
          title: const Text('恭喜！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('你已完成拼图！'),
              const SizedBox(height: 10),
              Text('用时: $time'),
              Text('得分: $score'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              child: const Text('再来一次'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                      (route) => false,
                );
              },
              child: const Text('返回主页'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  void _resetGame() {
    _gameService.resetGame();
    setState(() {
      _initFuture = _initializeGame();
    });
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸以便于布局计算
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("拼图游戏"),
        actions: [
          // 计时器显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                _formatTime(_gameService.elapsedSeconds),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_errorMessage != null) {
            return Center(child: Text(_errorMessage!));
          }

          return Column(
            children: [
              // 上方拼图区域
              Container(
                height: size.height * 0.6,
                color: Colors.grey.shade200,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 状态栏显示
                    _buildStatusBar(),

                    // 目标图像预览
                    _buildTargetImagePreview(),

                    // 拼图放置区
                    Expanded(child: Container(
                      key: _puzzleAreaKey,
                      child: _buildPuzzlePlacementArea(),
                    )),
                  ],
                ),
              ),

              // 中间分隔线
              Container(
                height: 4,
                color: Colors.blue.shade300,
              ),

              // 下方待放置拼图区域
              Expanded(child: _buildAvailablePiecesArea()),

              // 底部控制按钮
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Button_toRestart(context),
                    const SizedBox(width: 20),
                    Button_toHome(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  // 游戏状态栏
  Widget _buildStatusBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('难度: ${_getDifficultyText()}'),
          _buildGameStatusIndicator(),
        ],
      ),
    );
  }

  // 游戏状态指示器
  Widget _buildGameStatusIndicator() {
    Color statusColor;
    String statusText;

    switch (_gameService.status) {
      case GameStatus.notStarted:
        statusColor = Colors.grey;
        statusText = '未开始';
        break;
      case GameStatus.inProgress:
        statusColor = Colors.green;
        statusText = '进行中';
        break;
      case GameStatus.paused:
        statusColor = Colors.orange;
        statusText = '已暂停';
        break;
      case GameStatus.completed:
        statusColor = Colors.blue;
        statusText = '已完成';
        break;
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(statusText),
      ],
    );
  }

  // 难度文本
  String _getDifficultyText() {
    switch (widget.difficulty) {
      case 1: return '简单 (3×3)';
      case 2: return '中等 (4×4)';
      case 3: return '困难 (5×5)';
      default: return '简单 (3×3)';
    }
  }

  // 目标图像预览
  Widget _buildTargetImagePreview() {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _targetImage != null
          ? Center(
        child: RawImage(
          image: _targetImage,
          fit: BoxFit.contain,
        ),
      )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  // 拼图放置区
  Widget _buildPuzzlePlacementArea() {
    // 获取目标图像的尺寸
    final double targetWidth = _targetImage?.width.toDouble() ?? 300;
    final double targetHeight = _targetImage?.height.toDouble() ?? 300;

    // 计算可用空间
    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double availableHeight = MediaQuery.of(context).size.height * 0.4;

    // 取最小值确保为正方形
    final double squareSize = availableWidth < availableHeight ? availableWidth : availableHeight;
    
    // 计算缩放比例并保存到成员变量
    _scale = squareSize / Math.max(targetWidth, targetHeight);

    return Center(
      child: Container(
        width: squareSize,
        height: squareSize,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Stack(
          children: [
            // 已放置的拼图块（不能移动）- 使用中心点定位
            for (int i = 0; i < _gameService.placedPieces.length; i++)
              if (_gameService.placedPieces[i] != null)
                Positioned(
                  // 使用中心点定位，减去宽高的一半得到左上角坐标
                  left: _gameService.placedPieces[i]!.position.dx * _scale -
                        (_gameService.placedPieces[i]!.bounds.width * _scale / 2),
                  top: _gameService.placedPieces[i]!.position.dy * _scale -
                       (_gameService.placedPieces[i]!.bounds.height * _scale / 2),
                  child: RawImage(
                    image: _gameService.placedPieces[i]!.image,
                    width: _gameService.placedPieces[i]!.bounds.width * _scale,
                    height: _gameService.placedPieces[i]!.bounds.height * _scale,
                  ),
                ),

            // 当前拖动的拼图目标位置高亮 - 同样使用中心点定位
            if (_shouldHighlightTarget && _currentDraggingPiece != null)
              Positioned(
                // 修正：使用中心点定位，减去宽高的一半得到左上角坐标
                left: _currentDraggingPiece!.position.dx * _scale -
                      (_currentDraggingPiece!.bounds.width * _scale / 2),
                top: _currentDraggingPiece!.position.dy * _scale -
                     (_currentDraggingPiece!.bounds.height * _scale / 2),
                child: CustomPaint(
                  size: Size(
                    _currentDraggingPiece!.bounds.width * _scale,
                    _currentDraggingPiece!.bounds.height * _scale,
                  ),
                  painter: PuzzlePieceHighlightPainter(
                    image: _currentDraggingPiece!.image,
                    scale: _scale,
                    shapePath: _currentDraggingPiece!.shapePath,
                    bounds: _currentDraggingPiece!.bounds,
                  ),
                ),
              ),

            // 放置区域（用于接收拖拽）
            Positioned.fill(
              child: DragTarget<int>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    color: candidateData.isNotEmpty
                        ? Colors.green.withOpacity(0.1)
                        : Colors.transparent,
                  );
                },
                onWillAccept: (data) {
                  return data != null &&
                      _gameService.status == GameStatus.inProgress &&
                      data < _gameService.availablePieces.length;
                },
                onAccept: (pieceIndex) {
                  // 简化放置逻辑，直接尝试放置拼图块
                  if (_currentDraggingPiece != null) {
                    final targetPosition = _currentDraggingPiece!.nodeId;

                    if (targetPosition >= 0 &&
                        targetPosition < _gameService.placedPieces.length &&
                        _gameService.placedPieces[targetPosition] == null) {

                      // 直接放置拼图块
                      final success = _gameService.placePiece(
                        pieceIndex,
                        targetPosition
                      );

                      if (success) {
                        setState(() {});
                      }
                    }
                  }

                  // 重置拖动状态
                  setState(() {
                    _currentDraggingPiece = null;
                    _currentDraggingIndex = -1;
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

  Widget _buildPuzzleSlot(int index) {
    final placedPiece = _gameService.placedPieces.length > index
        ? _gameService.placedPieces[index]
        : null;

    return DragTarget<int>(
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.green.withOpacity(0.3)
                : Colors.grey.shade200,
            border: Border.all(
              color: candidateData.isNotEmpty ? Colors.green : Colors.grey,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: placedPiece != null
              ? Center(
            child: RawImage(
              image: placedPiece.image,
              fit: BoxFit.cover,
            ),
          )
              : const Center(child: Icon(Icons.add, color: Colors.grey)),
        );
      },
      onWillAccept: (data) {
        return _gameService.availablePieces.length > data!;
      },
      onAccept: (pieceIndex) {
        // 尝试放置拼图（移除第三个参数）
        final success = _gameService.placePiece(pieceIndex, index);
        if (success) {
          setState(() {});
        }
      },
    );
  }

// 待放置拼图区域
  Widget _buildAvailablePiecesArea() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              "待放置的拼图块:",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),

          // 可横向滑动的拼图块列表
          SizedBox(
            height: 100, // 固定高度确保可以显示
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _gameService.availablePieces.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _buildDraggablePuzzlePiece(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 可拖动的拼图块
  Widget _buildDraggablePuzzlePiece(int index) {
    if (index >= _gameService.availablePieces.length) {
      return const SizedBox.shrink();
    }

    final piece = _gameService.availablePieces[index];

    return Draggable<int>(
      data: index,
      feedback: Transform.scale(
        scale: 1.1,
        child: RawImage(
          image: piece.image,
          fit: BoxFit.contain,
          width: 40,
          height: 40,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: RawImage(
          image: piece.image,
          fit: BoxFit.contain,
          width: 40,
          height: 40,
        ),
      ),
      child: RawImage(
        image: piece.image,
        fit: BoxFit.contain,
        width: 40,
        height: 40,
      ),
      onDragStarted: () {
        // 记录当前拖动的拼图信息
        setState(() {
          _currentDraggingPiece = piece;
          _currentDraggingIndex = index;
          _shouldHighlightTarget = true; // 始终显示高亮
        });
      },
      // 修改拖动更新逻辑，修正距离计算
      onDragUpdate: (details) {
        if (_currentDraggingPiece != null) {
          _lastDragPosition = details.globalPosition;

          // 尝试获取拼图放置区域的RenderBox
          final RenderBox? puzzleAreaBox =
              _puzzleAreaKey.currentContext?.findRenderObject() as RenderBox?;

          // 如果无法获取，就不进行高亮
          if (puzzleAreaBox == null) {
            setState(() {
              _shouldHighlightTarget = false;
            });
            return;
          }

          // 将拖动点位置转换为相对于拼图区域的位置
          final localPosition = puzzleAreaBox.globalToLocal(_lastDragPosition);

          // 修复：计算正确的目标中心点位置
          // 因为实际渲染时我们用的是拼图位置和实际拼图块尺寸，这里也应该保持一致
          final targetCenter = Offset(
            _currentDraggingPiece!.position.dx * _scale,
            _currentDraggingPiece!.position.dy * _scale
          );

          // 使用拖动点到目标中心点的距离作为基准
          final distance = (localPosition - targetCenter).distance;

          // 计算合理的高亮阈值 - 使用拼图块尺寸的0.8倍
          final maxDimension = Math.max(
            _currentDraggingPiece!.bounds.width * _scale,
            _currentDraggingPiece!.bounds.height * _scale
          );
          final highlightThreshold = maxDimension * 0.8;

          setState(() {
            // 移除调试打印
            _shouldHighlightTarget = distance <= highlightThreshold;
          });
        }
      },
      onDragEnd: (details) {
        // 拖动结束重置信息
        _currentDraggingPiece = null;
        _currentDraggingIndex = -1;
        setState(() {
          _shouldHighlightTarget = false;
        });
      },
      onDragCompleted: () {
        setState(() {
          _shouldHighlightTarget = false;
        });
      },
    );
  }

  ElevatedButton Button_toRestart(BuildContext context){
    return ElevatedButton(
      onPressed:(){
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PuzzlePage(
            difficulty: widget.difficulty,
            imagePath: widget.imagePath,
          )),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh),
          SizedBox(width: 10),
          Text('重新开始', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  ElevatedButton Button_toHome(BuildContext context){
    return ElevatedButton(
      onPressed:(){
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
              (route) => false,
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home),
          SizedBox(width: 10),
          Text('返回主页', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
