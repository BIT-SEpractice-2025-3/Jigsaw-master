//游戏服务
import 'dart:async';
import '/models/puzzle_piece.dart';
// 游戏状态枚举
enum GameStatus {
  notStarted,  // 未开始
  inProgress,  // 进行中
  paused,      // 暂停
  completed    // 已完成
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

  // 游戏状态变化流
  final _statusController = StreamController<GameStatus>.broadcast();
  Stream<GameStatus> get statusStream => _statusController.stream;

  // 初始化游戏
  Future<void> initGame(List<PuzzlePiece> pieces, int difficulty) async {
    _difficulty = difficulty;
    _availablePieces = List.from(pieces);
    _placedPieces = List.filled(difficulty * difficulty, null);
    _elapsedSeconds = 0;
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

  // 尝试放置拼图碎片
  bool placePiece(int pieceIndex, int targetPosition) {
    if (_status != GameStatus.inProgress) return false;

    // TODO: 实现拼图放置逻辑
    // 1. 检查位置是否有效
    // 2. 检查是否已有碎片
    // 3. 移动碎片

    // 检查游戏是否完成
    _checkGameCompletion();

    return true;
  }

  // 移除已放置的拼图碎片
  PuzzlePiece? removePiece(int position) {
    if (_status != GameStatus.inProgress) return null;

    // TODO: 实现拼图移除逻辑
    return null;
  }

  // 检查游戏是否完成
  void _checkGameCompletion() {
    // TODO: 实现完成检查逻辑
    // 如果所有碎片都正确放置:
    // _status = GameStatus.completed;
    // _statusController.add(_status);
    // _stopTimer();
  }

  // 开始计时
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds++;
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
    _placedPieces = List.filled(_difficulty * _difficulty, null);
    _status = GameStatus.notStarted;
    _statusController.add(_status);
  }

  // 获取游戏分数
  int calculateScore() {
    // TODO: 实现分数计算逻辑
    // 可以基于时间、难度和使用的提示数量
    return 0;
  }

  // 释放资源
  void dispose() {
    _stopTimer();
    _statusController.close();
  }
}
