//游戏界面
//->主页
//->游戏界面
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import '../models/puzzle_piece.dart';
import 'home.dart';
import '../services/puzzle_generate_service.dart';
import '../services/puzzle_game_service.dart';

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
                    Expanded(child: _buildPuzzlePlacementArea()),
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

  PuzzlePiece? _currentDraggingPiece;
  int _currentDraggingIndex = -1;

  // 拼图放置区
  Widget _buildPuzzlePlacementArea() {
    // 获取目标图像的尺寸
    final double targetWidth = _targetImage?.width.toDouble() ?? 300;
    final double targetHeight = _targetImage?.height.toDouble() ?? 300;

    // 计算缩放比例以适应容器
    final double containerWidth = MediaQuery.of(context).size.width - 32;
    final double scale = containerWidth / targetWidth;
    final double scaledHeight = targetHeight * scale;

    return Container(
      width: containerWidth,
      height: scaledHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Stack(
        children: [
          // 已放置的拼图块（不能移动）
          for (int i = 0; i < _gameService.placedPieces.length; i++)
            if (_gameService.placedPieces[i] != null)
              Positioned(
                left: _gameService.placedPieces[i]!.position.dx * scale,
                top: _gameService.placedPieces[i]!.position.dy * scale,
                child: RawImage(
                  image: _gameService.placedPieces[i]!.image,
                  width: _gameService.placedPieces[i]!.image.width.toDouble() * scale,
                  height: _gameService.placedPieces[i]!.image.height.toDouble() * scale,
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
              onAcceptWithDetails: (details) {
                if (_currentDraggingPiece == null) return;
                print("1");
                final dropPosition = details.offset;

                // 将位置缩放到原始图像坐标系
                final double targetWidth = _targetImage?.width.toDouble() ?? 300;
                final double scale = (MediaQuery.of(context).size.width - 32) / targetWidth;

                final originalPosition = Offset(
                  dropPosition.dx / scale - 75,
                  dropPosition.dy / scale - 500,
                );

                // 使用当前拖动拼图的正确位置进行吸附判断
                final correctPosition = _currentDraggingPiece!.position;

                // 检查是否应该吸附到正确位置
                const double snapThreshold = 500.0;
                final distance = (originalPosition - correctPosition).distance;
                final shouldSnap = distance <= snapThreshold;
                // print(originalPosition);
                // print(correctPosition);
                // print(distance);
                if (shouldSnap) {
                  // 直接使用拼图的nodeId作为目标位置索引
                  final targetIndex = _currentDraggingPiece!.nodeId;

                  // 检查目标位置是否有效且为空
                  if (targetIndex >= 0 &&
                      targetIndex < _gameService.placedPieces.length &&
                      _gameService.placedPieces[targetIndex] == null) {

                    // 使用现有的placePiece方法
                    final success = _gameService.placePiece(
                        _currentDraggingIndex,
                        targetIndex,
                        originalPosition
                    );

                    if (success) {
                      setState(() {});
                    }
                  }
                }

                // 重置拖动信息
                _currentDraggingPiece = null;
                _currentDraggingIndex = -1;
              },
            ),
          ),
        ],
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
        // 获取拖拽释放的位置
        final RenderBox box = context.findRenderObject() as RenderBox;
        final dropPosition = box.localToGlobal(Offset.zero);

        // 尝试放置拼图（包含吸附逻辑）
        final success = _gameService.placePiece(pieceIndex, index, dropPosition);
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
          width: 80,
          height: 80,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: RawImage(
          image: piece.image,
          fit: BoxFit.contain,
          width: 80,
          height: 80,
        ),
      ),
      child: RawImage(
        image: piece.image,
        fit: BoxFit.contain,
        width: 80,
        height: 80,
      ),
      onDragStarted: () {
        // 记录当前拖动的拼图信息
        _currentDraggingPiece = piece;
        _currentDraggingIndex = index;
      },
      onDragEnd: (details) {
        // 拖动结束重置信息
        _currentDraggingPiece = null;
        _currentDraggingIndex = -1;
      },
      onDragCompleted: () {
        setState(() {});
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