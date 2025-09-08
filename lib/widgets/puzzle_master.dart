import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '/models/puzzle_piece.dart';
import '/services/puzzle_game_service.dart';
import '/services/puzzle_generate_service.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import '../widgets/save_detection_dialog.dart';
import '../utils/score_helper.dart';
import '../services/auth_service.dart';

// Add MasterPieceData definition here since we're removing game_save_service.dart
class MasterPieceData {
  final int nodeId;
  final double positionX;
  final double positionY;
  final double scale;
  final double rotation;
  final int group;

  MasterPieceData({
    required this.nodeId,
    required this.positionX,
    required this.positionY,
    required this.scale,
    required this.rotation,
    required this.group,
  });

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'positionX': positionX,
      'positionY': positionY,
      'scale': scale,
      'rotation': rotation,
      'group': group,
    };
  }

  factory MasterPieceData.fromJson(Map<String, dynamic> json) {
    return MasterPieceData(
      nodeId: json['nodeId'],
      positionX: json['positionX'],
      positionY: json['positionY'],
      scale: json['scale'],
      rotation: json['rotation'],
      group: json['group'],
    );
  }
}

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

  int? _selectedGroupId;
  bool _gameInitialized = false;
  SnapTarget? _snapTarget;
  Offset? _lastFocalPoint;

  // 新增：计时和分数状态
  int _currentScore = 0;
  int _currentTime = 0;
  bool _isGameRunning = false;

  // 新增：实时存档相关
  DateTime _lastSaveTime = DateTime.now();
  static const Duration _autoSaveInterval = Duration(seconds: 30); // 每30秒自动保存

  // 新增：待初始化的拼图块
  List<PuzzlePiece>? _pendingPieces;

  @override
  void initState() {
    super.initState();
    // 检查存档并初始化游戏
    _checkForSaveAndInitialize();

    // 监听吸附事件以更新UI
    _gameService.snapStream.listen((snapTarget) {
      if (mounted && _snapTarget != snapTarget) {
        setState(() {
          _snapTarget = snapTarget;
        });
      }
    });

    // 新增：监听分数变化
    _gameService.masterScoreStream.listen((score) {
      if (mounted) {
        setState(() {
          _currentScore = score;
        });
      }
    });

    // 新增：监听计时变化
    _gameService.timerStream.listen((seconds) {
      if (mounted) {
        setState(() {
          _currentTime = seconds;
        });

        // 检查是否需要自动保存
        _checkAutoSave();
      }
    });

    // 新增：监听游戏状态变化
    _gameService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isGameRunning = status == GameStatus.inProgress;
        });

        // 游戏完成时显示完成对话框
        if (status == GameStatus.completed) {
          _showCompletionDialog();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('大师模式'),
        backgroundColor: Colors.deepPurple.shade50,
        elevation: 0,
        actions: [
          // 新增：计时器显示
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
          // 新增：重置按钮
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('重置游戏'),
                  content: Text('确定要重置当前游戏吗？所有进度将丢失。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetGame();
                      },
                      child: Text('确定'),
                    ),
                  ],
                ),
              );
            },
            icon: Icon(Icons.refresh),
            tooltip: '重置游戏',
          ),
        ],
      ),
      body: Column(
        children: [
          // 新增：计分和游戏信息区域
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
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: _generateService.lastLoadedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: RawImage(
                            image: _generateService.lastLoadedImage!,
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
                        '大师模式',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                      Text(
                        _getDifficultyText(widget.difficulty),
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
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.shade100,
                        Colors.orange.shade100,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber.shade700,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _currentScore.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 拼图区域
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize =
                    ui.Size(constraints.maxWidth, constraints.maxHeight);

                if (!_gameInitialized && _pendingPieces != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _initializeGame(boardSize, _pendingPieces);
                    _pendingPieces = null;
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
                        if (_gameInitialized) _buildGroupControls(),

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

  void _rotateGroup(int groupId, double rotationDelta) {
    final groupPieces =
        _gameService.masterPieces.where((p) => p.group == groupId).toList();
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
        relativePos.dx * cos(rotationDelta) -
            relativePos.dy * sin(rotationDelta),
        relativePos.dx * sin(rotationDelta) +
            relativePos.dy * cos(rotationDelta),
      );

      // c. 计算块的新绝对位置 (pivot 的新位置)
      p.position = groupCenter + rotatedRelativePos;

      // d. 更新块自身的旋转角度
      p.rotation += rotationDelta;
    }
  }

  // 新增：显示游戏完成对话框
  void _showCompletionDialog() {
    // 游戏完成，删除服务器存档
    final authService = AuthService();
    if (authService.isLoggedIn) {
      authService
          .deleteSave('master', widget.difficulty)
          .catchError((e) => print('删除服务器存档失败: $e'));
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
              Text('🎉 你已成功完成大师模式拼图！'),
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
                        Text(_formatTime(_currentTime),
                            style: TextStyle(fontFamily: 'monospace')),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('⭐ 得分:',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                        Text(_currentScore.toString(),
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
              child: Text('再来一次'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // 返回到上一页
              },
              child: Text('返回'),
            ),
            // 新增：提交分数按钮
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _submitMasterScore(
                    _currentScore, _currentTime, widget.difficulty);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('提交分数'),
            ),
          ],
        );
      },
    );
  }

  // 新增：重置游戏
  void _resetGame() {
    _gameService.resetMasterGame();
    setState(() {
      _gameInitialized = false;
      _selectedGroupId = null;
      _snapTarget = null;
      _currentScore = 0;
      _currentTime = 0;
      _isGameRunning = false;
    });
  }

  // 新增：格式化时间显示
  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // 新增：提交大师模式分数
  Future<void> _submitMasterScore(
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
      print('大师模式分数提交失败: $e');
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
      case 4:
        return 'master';
      default:
        return 'master';
    }
  }

  Future<void> _initializeGame(ui.Size boardSize,
      [List<PuzzlePiece>? pieces]) async {
    if (_gameInitialized) return;
    final puzzlePieces = pieces ??
        await _generateService.generatePuzzle(
            widget.imageSource, widget.difficulty);
    _gameService.initMasterGame(puzzlePieces, boardSize);
    if (mounted) {
      setState(() {
        _gameInitialized = true;
        _isGameRunning = true;
      });
    }
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
            final groupPieces = _gameService.masterPieces
                .where((p) => p.group == groupID)
                .toList();

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
          if (_snapTarget != null &&
              _snapTarget!.draggedPieceId == pieceState.piece.nodeId) {
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
              final snappedRotation =
                  (currentRotation / baseAngle).round() * baseAngle;

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

  // 在 _PuzzleMasterPageState 类中，用下面的代码替换整个 _buildGroupControls 方法
  Widget _buildGroupControls() {
    if (_selectedGroupId == null) {
      return const SizedBox.shrink();
    }

    final groupPieces = _gameService.masterPieces
        .where((p) => p.group == _selectedGroupId!)
        .toList();
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
        final transformedVector =
            transform.transform3(Vector3(corner.dx, corner.dy, 0));
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
              child: const Icon(Icons.rotate_left,
                  color: Colors.blue, size: iconSize),
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
              child: const Icon(Icons.rotate_right,
                  color: Colors.blue, size: iconSize),
            ),
          ),
        ),
      ],
    );
  }

  // 新增：获取难度文本
  String _getDifficultyText(int difficulty) {
    switch (difficulty) {
      case 1:
        return '简单 (3×3)';
      case 2:
        return '中等 (4×4)';
      case 3:
        return '困难 (5×5)';
      default:
        return '大师模式';
    }
  }

  // 新增：检查存档并初始化游戏
  Future<void> _checkForSaveAndInitialize() async {
    final authService = AuthService();
    if (authService.isLoggedIn) {
      final saveData = await authService.loadSave('master', widget.difficulty);
      if (saveData != null) {
        final shouldLoadSave = await SaveDetectionDialog.showSaveDialog(
          context: context,
          gameMode: 'master',
          difficulty: widget.difficulty,
        );
        if (shouldLoadSave == true) {
          await _loadGameFromServer(saveData);
          return;
        } else if (shouldLoadSave == false) {
          try {
            await authService.deleteSave('master', widget.difficulty);
            print('用户选择不加载，已删除服务器存档');
          } catch (e) {
            print('删除服务器存档失败: $e');
          }
        }
      }
    }
    // 开始新游戏
    _initializeNewGame();
  }

  // 新增：初始化新游戏
  void _initializeNewGame() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pieces = await _generateService.generatePuzzle(
          widget.imageSource, widget.difficulty);
      setState(() {
        _pendingPieces = pieces;
      });
    });
  }

  // 新增：检查自动保存
  void _checkAutoSave() {
    final now = DateTime.now();
    if (now.difference(_lastSaveTime) >= _autoSaveInterval) {
      // 超过自动保存时间间隔，执行自动保存
      _lastSaveTime = now;
      _saveGame().catchError((e) => print('Auto save failed: $e'));
    }
  }

  // 新增：保存游戏
  Future<void> _saveGame() async {
    final currentPieces = _gameService.masterPieces
        .map((pieceState) => MasterPieceData(
              nodeId: pieceState.piece.nodeId,
              positionX: pieceState.position.dx,
              positionY: pieceState.position.dy,
              scale: pieceState.scale,
              rotation: pieceState.rotation,
              group: pieceState.group,
            ))
        .toList();

    final authService = AuthService();
    if (authService.isLoggedIn) {
      final saveData = {
        'gameMode': 'master',
        'difficulty': widget.difficulty,
        'elapsedSeconds': _currentTime,
        'currentScore': _currentScore,
        'imageSource': widget.imageSource,
        'placedPiecesIds': [],
        'availablePiecesIds': [],
        'masterPieces': currentPieces.map((p) => p.toJson()).toList(),
      };
      await authService.submitSave(saveData);
      print('Master mode save sent to server');
    }
  }

  // 新增：从服务器加载游戏
  Future<void> _loadGameFromServer(Map<String, dynamic> saveData) async {
    try {
      // 先生成拼图块
      final pieces = await _generateService.generatePuzzle(
          saveData['imageSource'], widget.difficulty);

      // 从存档恢复大师模式拼图块
      final masterPieces = (saveData['masterPieces'] as List).map((data) {
        final piece = pieces.firstWhere((p) => p.nodeId == data['nodeId']);
        return MasterPieceState(
          piece: piece,
          position: Offset(data['positionX'], data['positionY']),
          scale: data['scale'],
          rotation: data['rotation'],
          group: data['group'],
        );
      }).toList();

      // 重新初始化游戏服务
      _gameService.resetMasterGame();
      await _initializeGame(
          ui.Size(MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height),
          pieces);

      // 尝试设置恢复的状态
      try {
        _gameService.masterPieces = masterPieces;
        print('成功恢复大师模式拼图状态: ${masterPieces.length} 个拼图块');
      } catch (e) {
        print('无法直接设置 masterPieces，尝试其他方式: $e');
        // 如果无法直接设置，尝试通过其他方式恢复
        // 这里可能需要修改 PuzzleGameService 来支持状态恢复
      }

      setState(() {
        _gameInitialized = true;
        _isGameRunning = true;
        _currentScore = saveData['currentScore'];
        _currentTime = saveData['elapsedSeconds'];
      });
      _gameService.setElapsedTime(saveData['elapsedSeconds']);
      _gameService.startGame();

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
      print('加载服务器存档详细错误: $e');

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

        // 开始新游戏
        _initializeNewGame();
      }
    }
  }

  @override
  void dispose() {
    // 在页面销毁时保存游戏进度
    if (_gameService.status == GameStatus.inProgress) {
      _saveGame().catchError((e) => print('Save on dispose failed: $e'));
    }
    super.dispose();
  }
}

// 自定义 Painter 来绘制拼图块和发光效果
class _PuzzlePiecePainter extends CustomPainter {
  final PuzzlePiece piece;
  final bool isSelected;
  final SnapTarget? snapTarget;

  _PuzzlePiecePainter(
      {required this.piece, this.isSelected = false, this.snapTarget});

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
        (snapTarget!.draggedPieceId == piece.nodeId ||
            snapTarget!.targetPieceId == piece.nodeId)) {
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
