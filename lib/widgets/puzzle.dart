import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../models/puzzle_piece.dart';
import 'home.dart';
import '../services/puzzle_generate_service.dart';
import '../services/puzzle_game_service.dart';
import '../widgets/save_detection_dialog.dart';
import '../utils/score_helper.dart';
import '../services/auth_service.dart';
import '../services/audio_service.dart';

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
  bool _shouldHighlightTarget = false;
  Offset _lastDragPosition = Offset.zero;

  // 新增：计时和分数状态
  int _currentScore = 0;
  int _currentTime = 0;
  bool _isGameRunning = false;

  // 新增：实时存档相关
  DateTime _lastSaveTime = DateTime.now();
  static const Duration _autoSaveInterval = Duration(seconds: 30); // 每30秒自动保存

  // 新增：音效播放控制
  bool _snapPlayedDuringDrag = false;

  // 新增：步数计数器
  int _moveCount = 0;

  @override
  void initState() {
    super.initState();
    _gameService = PuzzleGameService();
    _generator = PuzzleGenerateService();
    _initFuture = _checkForSaveAndInitialize();
    final audioService = AudioService();
    if (!audioService.bgmPlaying) {
      audioService.playBgm();
    }

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
      // 只检查服务器上的存档
      final authService = AuthService();
      if (authService.isLoggedIn) {
        final saveData =
            await authService.loadSave('classic', widget.difficulty);
        if (saveData != null) {
          // 使用存档检测对话框
          final shouldLoadSave = await SaveDetectionDialog.showSaveDialog(
            context: context,
            gameMode: 'classic',
            difficulty: widget.difficulty,
          );
          if (shouldLoadSave == true) {
            await _loadGameFromServer(saveData);
            return;
          } else if (shouldLoadSave == false) {
            // 用户选择不加载存档，删除服务器上的存档
            try {
              await authService.deleteSave('classic', widget.difficulty);
            } catch (e) {}
          }
        }
      }

      // 开始新游戏
      await _initializeGame();
    } catch (e) {
      setState(() {
        _errorMessage = '初始化游戏失败: $e';
      });
    }
  }

  // 从服务器加载游戏
  Future<void> _loadGameFromServer(Map<String, dynamic> saveData) async {
    try {
      // 使用存档中的图片路径
      final pieces = await _generator.generatePuzzle(
          saveData['imageSource'], widget.difficulty);
      _targetImage = _generator.lastLoadedImage;
      // 初始化游戏服务但不立即开始
      await _gameService.initGameSafe(pieces, widget.difficulty);
      // 恢复拼图块状态
      _restorePuzzleState(pieces, saveData);
      // 恢复游戏状态
      _currentTime = saveData['elapsedSeconds'];
      _currentScore = saveData['currentScore'];

      // 设置游戏计时器的起始时间
      _gameService.setElapsedTime(saveData['elapsedSeconds']);

      // 启动游戏
      _gameService.startGame();
      _updateRealtimeScore();

      // 显示加载成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
      setState(() {
        _errorMessage = '加载存档失败: $e';
      });

      // 加载失败时显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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

        // 开始新游戏
        await _initializeGame();
      }
    }
  }

  // 恢复拼图块状态
  void _restorePuzzleState(
      List<PuzzlePiece> pieces, Map<String, dynamic> saveData) {
    try {
      // 根据存档恢复已放置的拼图块
      final placedPiecesIds = saveData['placedPiecesIds'] as List<dynamic>;

      // 遍历所有已放置的拼图块位置
      for (int position = 0; position < placedPiecesIds.length; position++) {
        final pieceId = placedPiecesIds[position];
        if (pieceId != null) {
          // 找到对应的拼图块在可用列表中的索引
          final pieceIndex = _gameService.availablePieces
              .indexWhere((p) => p.nodeId == pieceId);
          if (pieceIndex != -1) {
            // 尝试放置拼图块到指定位置
            final success = _gameService.placePiece(pieceIndex, position);
            if (success) {
            } else {}
          } else {}
        }
      }
    } catch (e) {
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

      // 随机化拼图块顺序
      pieces.shuffle();

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
    // 播放胜利音效
    AudioService().playSuccessSound();

    // 游戏完成，删除服务器存档
    final authService = AuthService();
    if (authService.isLoggedIn) {
      authService.deleteSave('classic', widget.difficulty);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // 使用实时分数而不是重新计算的分数
        final score = _currentScore;
        final time = _formatTime(_gameService.elapsedSeconds);

        return AlertDialog(
          title: const Row(
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
              const Text('🎉 你已成功完成拼图！'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('⏱️ 用时:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(time,
                            style: const TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('⭐ 得分:',
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
              style: TextButton.styleFrom(
                minimumSize: const Size(60, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('再来一次', style: TextStyle(fontSize: 13)),
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
              style: TextButton.styleFrom(
                minimumSize: const Size(60, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('返回主页', style: TextStyle(fontSize: 13)),
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
                minimumSize: const Size(70, 36),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('提交分数', style: TextStyle(fontSize: 13)),
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
      _moveCount = 0; // 新增：重置步数
      _isGameRunning = false;
      _lastSaveTime = DateTime.now(); // 重置存档时间
    });
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

      // 发送存档到服务器
      final authService = AuthService();
      if (authService.isLoggedIn) {
        final saveData = {
          'gameMode': 'classic',
          'difficulty': widget.difficulty,
          'elapsedSeconds': _currentTime,
          'currentScore': _currentScore,
          'imageSource': widget.imagePath ?? 'assets/images/default_puzzle.jpg',
          'placedPiecesIds':
              _gameService.placedPieces.map((p) => p?.nodeId).toList(),
          'availablePiecesIds':
              _gameService.availablePieces.map((p) => p.nodeId).toList(),
        };
        await authService.submitSave(saveData);
      }
    } catch (e) {}
  }

  // 新增：在拼图块放置后立即保存
  void _saveAfterPiecePlacement() {
    // 异步保存，但不等待完成
    _saveCurrentGameQuietly();
  }

  @override
  void dispose() {
    _gameService.dispose();
    super.dispose();
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
      const int baseScore = 1000; // 基础分数
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    const SizedBox(width: 4),
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

                    // 新增：步数显示
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.blue.shade300, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _moveCount.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Tooltip(
                            message: '移动步数：每次成功放置拼图块的次数',
                            child: Icon(
                              Icons.info_outline,
                              size: 14,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 分数显示
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
                            offset: const Offset(0, 2),
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
                          const SizedBox(width: 6),
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
                          const SizedBox(width: 4),
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
                      // 将 GlobalKey 移到真正的拼图正方形容器（在 _buildPuzzlePlacementArea 内）
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
              const SizedBox(width: 8),
              _buildRestartButton(), // 新增：重新开始按钮
              const SizedBox(width: 16),
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
      return const SizedBox.shrink();
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
      tooltipText = '已保存 ($secondsSinceLastSave秒前)';
    } else if (secondsSinceLastSave < 30) {
      indicatorColor = Colors.amber;
      indicatorIcon = Icons.cloud_queue;
      tooltipText = '将自动保存 (${30 - secondsSinceLastSave}秒后)';
    } else {
      indicatorColor = Colors.red;
      indicatorIcon = Icons.cloud_off;
      tooltipText = '需要保存 ($secondsSinceLastSave秒前)';
    }

    return Tooltip(
      message: tooltipText,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(width: 4),
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

  // 新增：重新开始按钮
  Widget _buildRestartButton() {
    return Tooltip(
      message: '重新开始游戏',
      child: InkWell(
        onTap: () {
          // 显示确认对话框
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('确认重新开始'),
              content: const Text('你确定要重新开始游戏吗？当前进度将会丢失。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _resetGame();
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange, width: 1),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh,
                size: 14,
                color: Colors.orange,
              ),
              SizedBox(width: 4),
              Text(
                '重新开始',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
                // 替换原来的 onAccept 回调为下面代码：
                onAccept: (nodeId) {
                  final pieceIndex = _gameService.availablePieces
                      .indexWhere((p) => p.nodeId == nodeId);

                  if (pieceIndex == -1) {
                    setState(() {
                      _currentDraggingPiece = null;
                      _shouldHighlightTarget = false;
                      _snapPlayedDuringDrag = false;
                    });
                    return;
                  }

                  if (_currentDraggingPiece != null) {
                    final targetPosition = _currentDraggingPiece!.nodeId;

                    if (_shouldHighlightTarget &&
                        _gameService.placedPieces[targetPosition] == null) {
                      final success =
                          _gameService.placePiece(pieceIndex, targetPosition);

                      if (success) {
                        setState(() {
                          _moveCount++; // 新增：增加步数
                        });
                        _updateRealtimeScore();
                        _saveAfterPiecePlacement();
                      }
                    }
                  }

                  setState(() {
                    _currentDraggingPiece = null;
                    _shouldHighlightTarget = false;
                    _snapPlayedDuringDrag = false;
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
          _shouldHighlightTarget = false; // 拖动开始时不立即显示高亮
          _snapPlayedDuringDrag = false; // 重置吸附音标志
        });
      },
      // 修改拖动更新逻辑，修正距离计算
      onDragUpdate: (details) {
        if (_currentDraggingPiece != null) {
          _lastDragPosition = details.globalPosition;

          final RenderBox? puzzleAreaBox =
              _puzzleAreaKey.currentContext?.findRenderObject() as RenderBox?;
          if (puzzleAreaBox == null) {
            setState(() => _shouldHighlightTarget = false);
            return;
          }

          final size = MediaQuery.of(context).size;
          final double availableWidth = size.width - 32;
          final double availableHeight = size.height * 0.4;
          final double squareSize = availableWidth < availableHeight
              ? availableWidth
              : availableHeight;
          final double currentScale =
              squareSize / (_targetImage?.width.toDouble() ?? 300);

          final double offsetX = (puzzleAreaBox.size.width - squareSize) / 2;
          final double offsetY = (puzzleAreaBox.size.height - squareSize) / 2;

          final localPosition = puzzleAreaBox.globalToLocal(_lastDragPosition) -
              Offset(offsetX + 2, offsetY + 2);

          final targetCenter = Offset(
              _currentDraggingPiece!.position.dx * currentScale,
              _currentDraggingPiece!.position.dy * currentScale);

          final targetRect = Rect.fromCenter(
            center: targetCenter,
            width: _currentDraggingPiece!.image.width.toDouble() *
                currentScale *
                0.55,
            height: _currentDraggingPiece!.image.height.toDouble() *
                currentScale *
                0.55,
          );

          final dragRect = Rect.fromCenter(
            center: localPosition,
            width: _currentDraggingPiece!.image.width.toDouble() *
                currentScale *
                0.55,
            height: _currentDraggingPiece!.image.height.toDouble() *
                currentScale *
                0.55,
          );

          final bool newShouldHighlight = targetRect.overlaps(dragRect);
          final bool oldShouldHighlight = _shouldHighlightTarget;

          setState(() {
            _shouldHighlightTarget = newShouldHighlight;
          });

          if (newShouldHighlight && !oldShouldHighlight) {
            _onPieceSnapped();
            _snapPlayedDuringDrag = true;
          }
        }
      },
      // 替换或修改 Draggable 的 onDragEnd 和 onDragCompleted：
      onDragEnd: (details) {
        _currentDraggingPiece = null;
        setState(() {
          _shouldHighlightTarget = false;
          _snapPlayedDuringDrag = false;
        });
      },
      onDragCompleted: () {
        setState(() {
          _shouldHighlightTarget = false;
          _snapPlayedDuringDrag = false;
        });
      },
    );
  }

  // 新增：有一个拼图块吸附成功的事件
  void _onPieceSnapped() {
    AudioService().playSnapSound();
  }
}
