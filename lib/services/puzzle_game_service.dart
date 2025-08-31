//游戏服务
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import '/models/puzzle_piece.dart';
// 游戏状态枚举
enum GameStatus {
  notStarted,  // 未开始
  inProgress,  // 进行中
  paused,      // 暂停
  completed    // 已完成
}

// 新增：描述一个潜在的吸附目标
class SnapTarget {
  final int draggedPieceId;
  final int targetPieceId;
  final String draggedPieceSide;
  final String targetPieceSide;

  SnapTarget({
    required this.draggedPieceId,
    required this.targetPieceId,
    required this.draggedPieceSide,
    required this.targetPieceSide,
  });
}

// 新增：大师模式下拼图块的状态
class MasterPieceState {
  final PuzzlePiece piece;
  ui.Offset position;
  double scale;
  double rotation;
  int group; // 用于标识吸附在一起的组

  MasterPieceState({
    required this.piece,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    required this.group,
  });
}

class PuzzleGameService {
  // 游戏状态
  GameStatus _status = GameStatus.notStarted;
  GameStatus get status => _status;

  // 游戏难度
  int _difficulty = 1;
  int get difficulty => _difficulty;

  // 游戏计时（秒）
  int _elapsedSeconds = 0;
  int get elapsedSeconds => _elapsedSeconds;
  Timer? _timer;

  // 拼图碎片
  List<PuzzlePiece> _availablePieces = []; // 待放置的碎片
  List<PuzzlePiece?> _placedPieces = [];   // 已放置的碎片

  // 获取拼图碎片（只读）
  List<PuzzlePiece> get availablePieces => List.unmodifiable(_availablePieces);
  List<PuzzlePiece?> get placedPieces => List.unmodifiable(_placedPieces);

  // --- 大师模式属性 ---
  List<MasterPieceState> masterPieces = [];
  SnapTarget? snapTarget; // 用于保存当前可吸附的目标

  // 游戏状态变化流
  final _statusController = StreamController<GameStatus>.broadcast();
  Stream<GameStatus> get statusStream => _statusController.stream;

  // 新增：计时器更新流
  final _timerController = StreamController<int>.broadcast();
  Stream<int> get timerStream => _timerController.stream;

  // 新增：吸附事件流，用于通知UI高亮
  final _snapController = StreamController<SnapTarget?>.broadcast();
  Stream<SnapTarget?> get snapStream => _snapController.stream;

  // 初始化大师模式游戏
  void initMasterGame(List<PuzzlePiece> pieces, ui.Size boardSize) {
    final random = Random();
    masterPieces.clear();
    for (int i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      masterPieces.add(MasterPieceState(
        piece: piece,
        // 在拼图区域内随机生成位置
        position: ui.Offset(
          random.nextDouble() * boardSize.width,
          random.nextDouble() * boardSize.height,
        ),
        // 固定大小为 0.5
        scale: 0.5,
        // 随机角度
        rotation: random.nextDouble() * 2 * pi,
        // 初始时，每个拼图块都在自己的组里
        group: i,
      ));
    }
    // 通知UI更新
    _statusController.add(GameStatus.inProgress);
  }

  // 更新大师模式中拼图块的变换
  void updateMasterPieceTransform(int pieceId, ui.Offset position, double scale, double rotation) {
    final index = masterPieces.indexWhere((p) => p.piece.nodeId == pieceId);
    if (index != -1) {
      masterPieces[index].position = position;
      masterPieces[index].scale = scale;
      masterPieces[index].rotation = rotation;
    }
  }

  // 检查是否有可吸附的拼图块
  void checkForSnapping(int draggedPieceId) {
    final draggedState = masterPieces.firstWhere((p) => p.piece.nodeId == draggedPieceId);

    for (var neighborEntry in draggedState.piece.neighbors.entries) {
      final side = neighborEntry.key;
      final neighborId = neighborEntry.value;

      if (neighborId == null) continue;

      final neighborState = masterPieces.firstWhere((p) => p.piece.nodeId == neighborId);

      // 如果已经在同一组，则跳过
      if (draggedState.group == neighborState.group) continue;

      // 1. 检查凹凸匹配
      final myEdgeType = draggedState.piece.edgeTypes[side];
      final neighborSide = _getOppositeSide(side);
      final neighborEdgeType = neighborState.piece.edgeTypes[neighborSide];
      if (myEdgeType == neighborEdgeType || myEdgeType == null) continue;

      // 2. 检查角度和大小
      final angleDifference = (draggedState.rotation - neighborState.rotation).abs() % (2 * pi);
      final scaleDifference = (draggedState.scale - neighborState.scale).abs();

      // 角度和大小必须非常接近 (角度差小于0.1弧度 ≈ 5.7度)
      if ((angleDifference > 0.1 && (2 * pi - angleDifference) > 0.1) || scaleDifference > 0.1) {
        continue;
      }

      // 3. 检查位置
      final myEdgeCenter = _getEdgeCenterInWorld(draggedState, side);
      final neighborEdgeCenter = _getEdgeCenterInWorld(neighborState, neighborSide);
      final distance = (myEdgeCenter - neighborEdgeCenter).distance;

      // 如果距离足够近 (阈值随缩放调整)
      if (distance < 40.0 * draggedState.scale) {
        // 发现可吸附目标
        snapTarget = SnapTarget(
          draggedPieceId: draggedPieceId,
          targetPieceId: neighborId,
          draggedPieceSide: side,
          targetPieceSide: neighborSide,
        );
        _snapController.add(snapTarget);
        return; // 找到一个即可
      }
    }

    // 如果没有找到可吸附的目标，清除旧目标并通知UI
    if (snapTarget != null) {
      snapTarget = null;
      _snapController.add(null);
    }
  }

  // 执行吸附操作
  void snapPieces() {
    if (snapTarget == null) return;

    final draggedState = masterPieces.firstWhere((p) => p.piece.nodeId == snapTarget!.draggedPieceId);
    final targetState = masterPieces.firstWhere((p) => p.piece.nodeId == snapTarget!.targetPieceId);

    // 1. 统一组内所有块的旋转和缩放为目标块的值
    final draggedGroup = draggedState.group;
    final targetGroup = targetState.group;

    for (var pieceState in masterPieces) {
      if (pieceState.group == draggedGroup) {
        pieceState.rotation = targetState.rotation;
        pieceState.scale = targetState.scale;
      }
    }

    // 2. 基于统一后的变换，精确计算对齐所需的位移
    final myEdgeCenter = _getEdgeCenterInWorld(draggedState, snapTarget!.draggedPieceSide);
    final neighborEdgeCenter = _getEdgeCenterInWorld(targetState, snapTarget!.targetPieceSide);
    final correctionVector = neighborEdgeCenter - myEdgeCenter;

    // 3. 移动整个被拖动的组，并将其合并到目标组
    for (var pieceState in masterPieces) {
      if (pieceState.group == draggedGroup) {
        pieceState.position += correctionVector;
        pieceState.group = targetGroup;
      }
    }

    // 4. 清理并检查游戏是否完成
    snapTarget = null;
    _snapController.add(null);
    print("吸附成功");
    _checkMasterGameCompletion();
  }

  // 获取边缘中心点在世界坐标系中的位置
  ui.Offset _getEdgeCenterInWorld(MasterPieceState state, String side) {
    final piece = state.piece;
    final halfSize = piece.pieceSize / 2;

    // 1. 获取边缘中心点相对于物理中心(pivot)的局部坐标
    ui.Offset localEdgeCenter;
    switch (side) {
      case 'top': localEdgeCenter = ui.Offset(0, -halfSize); break;
      case 'right': localEdgeCenter = ui.Offset(halfSize, 0); break;
      case 'bottom': localEdgeCenter = ui.Offset(0, halfSize); break;
      case 'left': localEdgeCenter = ui.Offset(-halfSize, 0); break;
      default: localEdgeCenter = ui.Offset.zero;
    }

    // 2. 应用旋转和缩放变换
    // 旋转
    final rotated = ui.Offset(
      localEdgeCenter.dx * cos(state.rotation) - localEdgeCenter.dy * sin(state.rotation),
      localEdgeCenter.dx * sin(state.rotation) + localEdgeCenter.dy * cos(state.rotation),
    );
    // 缩放
    final scaledAndRotated = rotated * state.scale;

    // 3. 添加 pivot 的全局位置
    return scaledAndRotated + state.position;
  }

  // 获取相对的边
  String _getOppositeSide(String side) {
    switch (side) {
      case 'top': return 'bottom';
      case 'right': return 'left';
      case 'bottom': return 'top';
      case 'left': return 'right';
      default: return '';
    }
  }

  // TODO: 实现拼图块分组
  // 当两个拼图块或组吸附时，将它们合并到同一个组中
  void snapPieces_old(int pieceId1, int pieceId2) {
    // 1. 将 pieceId2 所在组的所有拼图块的 group ID 更新为 pieceId1 的 group ID
    // 2. 检查是否所有拼图块都在同一个组中，如果是，则游戏完成
    _checkMasterGameCompletion();
  }

  // TODO: 检查大师模式游戏是否完成
  void _checkMasterGameCompletion() {
    if (masterPieces.isEmpty) return;
    final firstGroup = masterPieces.first.group;
    final allInOneGroup = masterPieces.every((p) => p.group == firstGroup);

    if (allInOneGroup) {
      // 还需要检查最终形成的图形是否在拼图区域内并填满
      // 这是一个复杂的几何问题，暂时简化为成组就算完成
      _status = GameStatus.completed;
      _statusController.add(_status);
      _stopTimer();
    }
  }


  // 初始化游戏
  Future<void> initGame(List<PuzzlePiece> pieces, int difficulty) async {
    _difficulty = difficulty;
    _availablePieces = List.from(pieces);
    // 修正：根据难度计算正确的网格大小
    final gridSize = difficulty + 2;
    _placedPieces = List.filled(gridSize * gridSize, null);
    _elapsedSeconds = 0;
    _timerController.add(_elapsedSeconds); // 初始化时通知UI
    _status = GameStatus.notStarted;
    _statusController.add(_status);
  }

  // 开始游戏
  void startGame() {
    if (_status == GameStatus.notStarted || _status == GameStatus.paused) {
      _status = GameStatus.inProgress;
      _statusController.add(_status);
      _startTimer();
    }
  }

  // 暂停游戏
  void pauseGame() {
    if (_status == GameStatus.inProgress) {
      _status = GameStatus.paused;
      _statusController.add(_status);
      _stopTimer();
    }
  }

  // 简化放置拼图的逻辑，不再需要位置参数
  bool placePiece(int pieceIndex, int targetPosition) {
    // 验证参数
    if (_status != GameStatus.inProgress) return false;
    if (targetPosition < 0 || targetPosition >= _placedPieces.length) return false;
    if (_placedPieces[targetPosition] != null) return false;
    if (pieceIndex < 0 || pieceIndex >= _availablePieces.length) return false;

    // 获取并移除待放置的拼图块（原始）
    final original = _availablePieces.removeAt(pieceIndex);

    // 计算目标格的行列并生成对齐到该格中心的新 position
    final gridSize = _difficulty + 2;
    final row = targetPosition ~/ gridSize;
    final col = targetPosition % gridSize;

    // 使用原始 piece 的 pieceSize（由 generate 提供）来计算格子大小与中心
    final double pieceSize = original.pieceSize;
    final newCenter = ui.Offset(col * pieceSize + pieceSize / 2, row * pieceSize + pieceSize / 2);

    // 由于 PuzzlePiece 的字段为 final，创建一个新的 PuzzlePiece 实例用于 placed 列表
    final placedPiece = PuzzlePiece(
      image: original.image,
      nodeId: original.nodeId,
      position: newCenter,           // 对齐到目标格中心（原图坐标系）
      shapePath: original.shapePath,
      bounds: original.bounds,
      pieceSize: original.pieceSize,
      pivot: original.pivot,
      neighbors: original.neighbors,
      edgeTypes: original.edgeTypes,
    );

    // 放置到目标位置
    _placedPieces[targetPosition] = placedPiece;

    // 检查游戏是否完成
    _checkGameCompletion();

    return true;
  }

  // 移除已放置的拼图碎片
  PuzzlePiece? removePiece(int position) {
    if (_status != GameStatus.inProgress) return null;
    if (position < 0 || position >= _placedPieces.length || _placedPieces[position] == null) {
      return null;
    }

    final piece = _placedPieces[position];
    _placedPieces[position] = null;
    _availablePieces.add(piece!);
    return piece;
  }

  // 在拼图板上移动拼图块
  void movePieceOnBoard(int fromPosition, int toPosition) {
    if (_status != GameStatus.inProgress) return;
    if (fromPosition < 0 || fromPosition >= _placedPieces.length || toPosition < 0 || toPosition >= _placedPieces.length) return;

    final piece = _placedPieces[fromPosition];
    // 允许交换
    _placedPieces[fromPosition] = _placedPieces[toPosition];
    _placedPieces[toPosition] = piece;

    _checkGameCompletion();
  }

  // 检查游戏是否完成
  void _checkGameCompletion() {
    // 检查是否所有碎片都正确放置
    bool allPiecesCorrectlyPlaced = true;
    for (int i = 0; i < _placedPieces.length; i++) {
      // 如果某个位置为空，或者位置上的拼图块ID与位置索引不匹配，则未完成
      if (_placedPieces[i] == null || _placedPieces[i]!.nodeId != i) {
        allPiecesCorrectlyPlaced = false;
        break;
      }
    }

    if (allPiecesCorrectlyPlaced) {
      _status = GameStatus.completed;
      _statusController.add(_status);
      _stopTimer();
    }
  }

  // 开始计时
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
      _timerController.add(_elapsedSeconds); // 每秒通知UI
    });
  }

  // 停止计时
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // 重置游戏
  void resetGame() {
    _stopTimer();
    _elapsedSeconds = 0;
    _timerController.add(_elapsedSeconds); // 重置时通知UI
    _placedPieces = List.filled((_difficulty + 2) * (_difficulty + 2), null);
    _status = GameStatus.notStarted;
    _statusController.add(_status);
  }

  // 获取游戏分数
  int calculateScore() {
    if (_status != GameStatus.completed) return 0;

    // 分数计算逻辑：基于时间、难度和完成度
    final int baseScore = 1000; // 基础分数
    final int timePenalty = _elapsedSeconds * 10; // 时间惩罚（每秒扣10分）
    final int difficultyBonus = _difficulty * 200; // 难度奖励

    // 计算最终分数（确保不为负数）
    int finalScore = baseScore - timePenalty + difficultyBonus;

    // 确保分数不为负
    if (finalScore < 0) {
      finalScore = 0;
    }

    // 根据完成度调整分数（所有碎片都正确放置，所以是100%）
    final double completionRate = 1.0; // 100%完成
    finalScore = (finalScore * completionRate).round();

    return finalScore;
  }

  // 释放资源
  void dispose() {
    _stopTimer();
    _statusController.close();
    _timerController.close(); // 关闭计时器流
    _snapController.close(); // 关闭吸附事件流
  }
}
