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
import '../services/game_save_service.dart';
import '../widgets/save_detection_dialog.dart';
import '../utils/score_helper.dart';

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

    // 简化绘制逻辑：直接缩放路径以适应画布大小
    // 原始路径的边界是 `this.bounds`
    // 画布的大小是 `size`
    final scaleX = size.width / bounds.width;
    final scaleY = size.height / bounds.height;

    final matrix = Matrix4.identity()..scale(scaleX, scaleY);
    final finalPath = shapePath.transform(matrix.storage);

    // 绘制填充和边框
    canvas.drawPath(finalPath, fillPaint);
    canvas.drawPath(finalPath, glowPaint);
    canvas.drawPath(finalPath, borderPaint);
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

  // 新增：计时和分数状态
  int _currentScore = 0;
  int _currentTime = 0;
  bool _isGameRunning = false;

  // 新增：实时存档相关
  DateTime _lastSaveTime = DateTime.now();
  static const Duration _autoSaveInterval = Duration(seconds: 30); // 每30秒自动保存

  @override
  void initState() {
    super.initState();
    _gameService = PuzzleGameService();
    _generator = PuzzleGenerateService();
    _initFuture = _checkForSaveAndInitialize();

    // 监听游戏状态变化
    _gameService.statusStream.listen((status) {
      if (status == GameStatus.completed) {
        _showCompletionDialog();
      }
      if (mounted) {
        setState(() {
          _isGameRunning = status == GameStatus.inProgress;
          // 状态变化时也更新分数
          _updateRealtimeScore();
        });
      }
    });

    // 新增：监听计时器更新
    _gameService.timerStream.listen((seconds) {
      if (mounted) {
        setState(() {
          _currentTime = seconds;
          // 实时更新分数
          _updateRealtimeScore();
        });

        // 检查是否需要自动保存
        _checkAutoSave();
      }
    });
  }

  // 检查存档并初始化游戏
  Future<void> _checkForSaveAndInitialize() async {
    try {
      // 使用存档检测对话框
      final shouldLoadSave = await SaveDetectionDialog.showSaveDialog(
        context: context,
        gameMode: 'classic',
        difficulty: widget.difficulty,
      );

      if (shouldLoadSave == true) {
        await _loadGameFromSave();
        return;
      } else if (shouldLoadSave == false) {
        // 删除旧存档，开始新游戏
        await GameSaveService.deleteSave('classic', widget.difficulty);
      }

      // 开始新游戏
      await _initializeGame();
    } catch (e) {
      setState(() {
        _errorMessage = '初始化游戏失败: $e';
      });
    }
  }

  // 从存档加载游戏
  Future<void> _loadGameFromSave() async {
    try {
      final gameSave =
          await GameSaveService.loadGame('classic', widget.difficulty);
      if (gameSave == null) {
        throw Exception('存档数据无效');
      }

      // 使用存档中的图片路径
      final pieces = await _generator.generatePuzzle(
          gameSave.imageSource, widget.difficulty);
      _targetImage = _generator.lastLoadedImage;

      // 初始化游戏服务但不立即开始
      await _gameService.initGameSafe(pieces, widget.difficulty);

      // 恢复拼图块状态
      _restorePuzzleState(pieces, gameSave);

      // 恢复游戏状态
      _currentTime = gameSave.elapsedSeconds;
      _currentScore = gameSave.currentScore;

      // 设置游戏计时器的起始时间
      _gameService.setElapsedTime(gameSave.elapsedSeconds);

      // 启动游戏
      _gameService.startGame();
      _updateRealtimeScore();

      // 显示加载成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('游戏进度已恢复'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('加载存档详细错误: $e');
      setState(() {
        _errorMessage = '加载存档失败: $e';
      });

      // 加载失败时显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('加载存档失败，将开始新游戏'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );

        // 删除损坏的存档并开始新游戏
        await GameSaveService.deleteSave('classic', widget.difficulty);
        await _initializeGame();
      }
    }
  }

  // 恢复拼图块状态
  void _restorePuzzleState(List<PuzzlePiece> pieces, GameSave gameSave) {
    try {
      // 创建新的可修改列表来替换当前状态
      final newPlacedPieces = <PuzzlePiece?>[];
      final newAvailablePieces = <PuzzlePiece>[];

      // 根据存档恢复已放置的拼图块
      for (int i = 0; i < gameSave.placedPiecesIds.length; i++) {
        final pieceId = gameSave.placedPiecesIds[i];
        if (pieceId != null) {
          try {
            final piece = pieces.firstWhere((p) => p.nodeId == pieceId);
            newPlacedPieces.add(piece);
          } catch (e) {
            print('找不到拼图块ID: $pieceId');
            newPlacedPieces.add(null);
          }
        } else {
          newPlacedPieces.add(null);
        }
      }

      // 根据存档恢复可用拼图块
      for (final pieceId in gameSave.availablePiecesIds) {
        try {
          final piece = pieces.firstWhere((p) => p.nodeId == pieceId);
          newAvailablePieces.add(piece);
        } catch (e) {
          print('找不到可用拼图块ID: $pieceId');
        }
      }

      // 使用反射或直接访问来替换列表（如果GameService提供了setter方法）
      // 这里假设GameService有重新初始化的方法
      _gameService.restoreGameStateSafe(newPlacedPieces, newAvailablePieces);
    } catch (e) {
      print('恢复拼图状态失败: $e');
      // 如果恢复失败，抛出异常让上层处理
      throw Exception('恢复游戏状态失败: $e');
    }
  }

  Future<void> _initializeGame() async {
    try {
      // 使用默认图片或用户选择的图片
      final imageSource =
          widget.imagePath ?? 'assets/images/default_puzzle.jpg';

      // 生成拼图碎片并获取目标图像
      final pieces =
          await _generator.generatePuzzle(imageSource, widget.difficulty);

      // 获取缓存的完整图像
      _targetImage = _generator.lastLoadedImage;

      await _gameService.initGame(pieces, widget.difficulty);
      _gameService.startGame();
      // 初始化实时分数
      _updateRealtimeScore();
    } catch (e) {
      setState(() {
        _errorMessage = '初始化游戏失败: $e';
      });
    }
  }

  void _showCompletionDialog() {
    // 游戏完成，删除存档
    GameSaveService.deleteSave('classic', widget.difficulty);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 使用实时分数而不是重新计算的分数
        final score = _currentScore;
        final time = _formatTime(_gameService.elapsedSeconds);

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.celebration, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text('恭喜完成！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎉 你已成功完成拼图！'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('⏱️ 用时:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(time, style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('⭐ 得分:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(score.toString(),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700)),
                      ],
                    ),
                  ],
                ),
              ),
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
            // 新增：提交分数按钮
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // 使用实时分数而不是重新计算的分数
                await _submitScore(_currentScore, _gameService.elapsedSeconds,
                    widget.difficulty);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('提交分数'),
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
      _currentTime = 0;
      _currentScore = 0; // 重置分数
      _isGameRunning = false;
      _lastSaveTime = DateTime.now(); // 重置存档时间
    });
  }

  // 保存当前游戏进度
  Future<void> _saveCurrentGame() async {
    try {
      // 只有游戏进行中时才保存
      if (_gameService.status != GameStatus.inProgress) {
        return;
      }

      final success = await GameSaveService.saveGame(
        gameMode: 'classic',
        difficulty: widget.difficulty,
        elapsedSeconds: _currentTime,
        currentScore: _currentScore,
        imageSource: widget.imagePath ?? 'assets/images/default_puzzle.jpg',
        placedPieces: _gameService.placedPieces,
        availablePieces: _gameService.availablePieces,
      );

      if (success) {
        _lastSaveTime = DateTime.now(); // 更新最后保存时间
        print('游戏进度已保存');
      } else {
        print('游戏进度保存失败');
      }
    } catch (e) {
      print('保存游戏进度时出错: $e');
    }
  }

  // 新增：检查是否需要自动保存
  void _checkAutoSave() {
    if (_gameService.status == GameStatus.inProgress) {
      final now = DateTime.now();
      final timeSinceLastSave = now.difference(_lastSaveTime);

      // 如果距离上次保存超过指定间隔，或者是重要节点（每放置5个拼图块）
      final placedCount =
          _gameService.placedPieces.where((piece) => piece != null).length;
      final shouldSaveByTime = timeSinceLastSave >= _autoSaveInterval;
      final shouldSaveByProgress =
          placedCount > 0 && placedCount % 5 == 0; // 每5个拼图块保存一次

      if (shouldSaveByTime || shouldSaveByProgress) {
        _saveCurrentGameQuietly(); // 静默保存，不显示提示
      }
    }
  }

  // 新增：静默保存游戏进度（不显示UI提示）
  Future<void> _saveCurrentGameQuietly() async {
    try {
      if (_gameService.status != GameStatus.inProgress) {
        return;
      }

      final success = await GameSaveService.saveGame(
        gameMode: 'classic',
        difficulty: widget.difficulty,
        elapsedSeconds: _currentTime,
        currentScore: _currentScore,
        imageSource: widget.imagePath ?? 'assets/images/default_puzzle.jpg',
        placedPieces: _gameService.placedPieces,
        availablePieces: _gameService.availablePieces,
      );

      if (success) {
        _lastSaveTime = DateTime.now();
        print(
            '游戏进度静默保存成功 (时间: ${_formatTime(_currentTime)}, 分数: $_currentScore)');
      }
    } catch (e) {
      print('静默保存游戏进度时出错: $e');
    }
  }

  // 新增：在拼图块放置后立即保存
  void _saveAfterPiecePlacement() {
    // 异步保存，但不等待完成
    _saveCurrentGameQuietly();
  }

  @override
  void dispose() {
    // 在页面销毁时保存游戏进度（同步方式，避免异步问题）
    if (_gameService.status == GameStatus.inProgress) {
      // 使用同步方式保存，避免dispose时的异步问题
      _saveGameSync();
    }
    _gameService.dispose();
    super.dispose();
  }

  // 同步保存游戏（用于dispose时调用）
  void _saveGameSync() {
    try {
      // 由于dispose时无法使用异步，这里记录需要保存的状态
      // 实际保存在下次启动时进行
      print('标记游戏需要保存: 模式=classic, 难度=${widget.difficulty}, 分数=$_currentScore');
    } catch (e) {
      print('标记保存状态失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取屏幕尺寸以便于布局计算
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("拼图游戏"),
        backgroundColor: Colors.deepPurple.shade50,
        elevation: 0,
        actions: [
          // 新增：计时器显示（与puzzle_master相同风格）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isGameRunning
                      ? Colors.green.shade100
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isGameRunning ? Colors.green : Colors.grey,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isGameRunning ? Icons.timer : Icons.timer_off,
                      size: 16,
                      color: _isGameRunning
                          ? Colors.green.shade700
                          : Colors.grey.shade600,
                    ),
                    SizedBox(width: 4),
                    Text(
                      _formatTime(_currentTime),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _isGameRunning
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
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
              // 新增：游戏信息栏（与puzzle_master相同风格）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 预览图
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                      child: _targetImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: RawImage(
                                image: _targetImage!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),

                    const SizedBox(width: 16),

                    // 游戏信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '经典拼图',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple.shade700,
                            ),
                          ),
                          Text(
                            _getDifficultyText(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 分数显示
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getScoreColor().shade100,
                            _getScoreColor().shade200,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _getScoreColor().shade300, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: _getScoreColor().withOpacity(0.3),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: _getScoreColor().shade700,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return ScaleTransition(
                                  scale: animation, child: child);
                            },
                            child: Text(
                              _currentScore.toString(),
                              key: ValueKey<int>(
                                  _currentScore), // 重要：使用分数作为key来触发动画
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor().shade700,
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Tooltip(
                            message: '实时分数：基础1000分 - 时间惩罚 - 难度奖励 + 放置奖励',
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: _getScoreColor().shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 上方拼图区域
              Container(
                height: size.height * 0.6,
                color: Colors.grey.shade200,
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    // 状态栏显示
                    _buildStatusBar(),

                    // 拼图放置区
                    Expanded(
                        child: Container(
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
          Row(
            children: [
              _buildAutoSaveIndicator(), // 新增：存档状态指示器
              SizedBox(width: 16),
              _buildGameStatusIndicator(),
            ],
          ),
        ],
      ),
    );
  }

  // 新增：自动存档状态指示器
  Widget _buildAutoSaveIndicator() {
    if (_gameService.status != GameStatus.inProgress) {
      return SizedBox.shrink();
    }

    final now = DateTime.now();
    final timeSinceLastSave = now.difference(_lastSaveTime);
    final secondsSinceLastSave = timeSinceLastSave.inSeconds;

    // 根据距离上次保存的时间显示不同状态
    Color indicatorColor;
    IconData indicatorIcon;
    String tooltipText;

    if (secondsSinceLastSave < 10) {
      indicatorColor = Colors.green;
      indicatorIcon = Icons.cloud_done;
      tooltipText = '已保存 (${secondsSinceLastSave}秒前)';
    } else if (secondsSinceLastSave < 30) {
      indicatorColor = Colors.amber;
      indicatorIcon = Icons.cloud_queue;
      tooltipText = '将自动保存 (${30 - secondsSinceLastSave}秒后)';
    } else {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.cloud_off;
      tooltipText = '需要保存 (${secondsSinceLastSave}秒前)';
    }

    return Tooltip(
      message: tooltipText,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: indicatorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: indicatorColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              indicatorIcon,
              size: 14,
              color: indicatorColor,
            ),
            SizedBox(width: 4),
            Text(
              '存档',
              style: TextStyle(
                fontSize: 12,
                color: indicatorColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

  // 新增：获取难度文本
  String _getDifficultyText() {
    switch (widget.difficulty) {
      case 1:
        return '简单 (3×3)';
      case 2:
        return '中等 (4×4)';
      case 3:
        return '困难 (5×5)';
      default:
        return '简单 (3×3)';
    }
  }

  // 拼图放置区
  Widget _buildPuzzlePlacementArea() {
    // 获取目标图像的尺寸
    final double targetWidth = _targetImage?.width.toDouble() ?? 300;

    // 计算可用空间
    final double availableWidth = MediaQuery.of(context).size.width - 32;
    final double availableHeight = MediaQuery.of(context).size.height * 0.4;

    // 取最小值确保为正方形
    final double squareSize =
        availableWidth < availableHeight ? availableWidth : availableHeight;

    // 修正：因为图片已经是正方形，所以 targetWidth 和 targetHeight 相等
    // 直接使用 targetWidth 或 targetHeight 即可
    _scale = squareSize / targetWidth;

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
            // 已放置的拼图块（不能移动）- 使用 pivot 精确定位，使用 image 尺寸渲染
            for (int i = 0; i < _gameService.placedPieces.length; i++)
              if (_gameService.placedPieces[i] != null)
                Positioned(
                  left: _gameService.placedPieces[i]!.position.dx * _scale -
                      (_gameService.placedPieces[i]!.pivot.dx * _scale),
                  top: _gameService.placedPieces[i]!.position.dy * _scale -
                      (_gameService.placedPieces[i]!.pivot.dy * _scale),
                  child: RawImage(
                    image: _gameService.placedPieces[i]!.image,
                    width:
                        (_gameService.placedPieces[i]!.image.width.toDouble()) *
                            _scale,
                    height: (_gameService.placedPieces[i]!.image.height
                            .toDouble()) *
                        _scale,
                  ),
                ),

            // 当前拖动的拼图目标位置高亮 - 使用 image 尺寸并与 RawImage 对齐
            if (_shouldHighlightTarget && _currentDraggingPiece != null)
              Positioned(
                left: _currentDraggingPiece!.position.dx * _scale -
                    (_currentDraggingPiece!.pivot.dx * _scale),
                top: _currentDraggingPiece!.position.dy * _scale -
                    (_currentDraggingPiece!.pivot.dy * _scale),
                child: CustomPaint(
                  size: Size(
                    _currentDraggingPiece!.image.width.toDouble() * _scale,
                    _currentDraggingPiece!.image.height.toDouble() * _scale,
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
                onWillAccept: (nodeId) {
                  // 修正：现在接收的是 nodeId
                  return nodeId != null &&
                      _gameService.status == GameStatus.inProgress;
                },
                onAccept: (nodeId) {
                  // 修正：通过 nodeId 找到 pieceIndex
                  final pieceIndex = _gameService.availablePieces
                      .indexWhere((p) => p.nodeId == nodeId);

                  if (pieceIndex == -1) {
                    // Piece not found
                    // 重置拖动状态
                    setState(() {
                      _currentDraggingPiece = null;
                      _currentDraggingIndex = -1;
                      _shouldHighlightTarget = false;
                    });
                    return;
                  }

                  // 简化放置逻辑，直接尝试放置拼图块
                  if (_currentDraggingPiece != null) {
                    final targetPosition = _currentDraggingPiece!.nodeId;

                    if (_shouldHighlightTarget &&
                        _gameService.placedPieces[targetPosition] == null) {
                      // 直接放置拼图块
                      final success =
                          _gameService.placePiece(pieceIndex, targetPosition);

                      if (success) {
                        // 放置成功后立即更新分数
                        _updateRealtimeScore();
                        // 放置成功后立即保存游戏进度
                        _saveAfterPiecePlacement();
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

  // 新增：待放置拼图区域
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
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _gameService.availablePieces.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Center(
                    heightFactor: 0.6,
                    child: _buildDraggablePuzzlePiece(index),
                  ),
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
      // 修正：传递 nodeId 而不是 index，避免 stale index 问题
      data: piece.nodeId,
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
          _shouldHighlightTarget = false; // 拖动开始时不立即显示高亮
        });
      },
      // 修改拖动更新逻辑，修正距离计算
      onDragUpdate: (details) {
        if (_currentDraggingPiece != null) {
          _lastDragPosition = details.globalPosition;

          // 尝试获取拼图放置区域的RenderBox
          final RenderBox? puzzleAreaBox =
              _puzzleAreaKey.currentContext?.findRenderObject() as RenderBox?;

          if (puzzleAreaBox == null) {
            setState(() {
              _shouldHighlightTarget = false;
            });
            return;
          }

          final localPosition = puzzleAreaBox.globalToLocal(_lastDragPosition);

          final targetCenter = Offset(
              _currentDraggingPiece!.position.dx * _scale,
              _currentDraggingPiece!.position.dy * _scale);

          // 使用图片真实尺寸计算阈值，保持与渲染一致
          final maxDimension = Math.max(
              _currentDraggingPiece!.image.width.toDouble() * _scale,
              _currentDraggingPiece!.image.height.toDouble() * _scale);
          final highlightThreshold = maxDimension * 0.8;

          final distance = (localPosition - targetCenter).distance;

          setState(() {
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

  ElevatedButton Button_toRestart(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => PuzzlePage(
                    difficulty: widget.difficulty,
                    imagePath: widget.imagePath,
                  )),
        );
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.refresh, size: 18),
          SizedBox(width: 6),
          Text('重新开始', style: TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // 新增：提交分数到服务器
  Future<void> _submitScore(
      int score, int timeInSeconds, int difficulty) async {
    try {
      await ScoreSubmissionHelper.submitGameScore(
        context: context,
        score: score,
        timeInSeconds: timeInSeconds,
        difficulty: _getDifficultyString(difficulty),
      );
    } catch (e) {
      // 错误已经在ScoreSubmissionHelper中处理，这里不需要额外处理
      print('分数提交失败: $e');
    }
  }

  // 新增：将难度数字转换为字符串
  String _getDifficultyString(int difficulty) {
    switch (difficulty) {
      case 1:
        return 'easy';
      case 2:
        return 'medium';
      case 3:
        return 'hard';
      default:
        return 'easy';
    }
  }

  // 新增：根据分数返回不同颜色
  MaterialColor _getScoreColor() {
    if (_currentScore >= 1200) {
      return Colors.green; // 高分 - 绿色
    } else if (_currentScore >= 800) {
      return Colors.amber; // 中等分数 - 琥珀色
    } else if (_currentScore >= 400) {
      return Colors.orange; // 低分 - 橙色
    } else {
      return Colors.red; // 很低分 - 红色
    }
  }

  // 新增：实时更新分数
  void _updateRealtimeScore() {
    if (_gameService.status == GameStatus.inProgress) {
      // 实时分数计算：基础分数 - 时间惩罚 + 难度奖励
      final int baseScore = 1000; // 基础分数
      final int timePenalty = _currentTime * 2; // 每秒扣2分（比最终分数计算更温和）
      final int difficultyBonus = widget.difficulty * 100; // 难度奖励

      // 计算已放置的拼图块数量奖励
      final int placedCount =
          _gameService.placedPieces.where((piece) => piece != null).length;
      final int placementBonus = (placedCount * 50); // 每放置一个块加50分

      int realtimeScore =
          baseScore - timePenalty + difficultyBonus + placementBonus;

      // 确保分数不为负
      if (realtimeScore < 0) {
        realtimeScore = 0;
      }

      setState(() {
        _currentScore = realtimeScore;
      });
    }
  }
}
