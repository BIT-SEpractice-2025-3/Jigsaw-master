// 游戏存档服务
// 负责保存和加载游戏进度

import 'dart:ui'; // For Offset
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart'; // Assuming this provides token management

// 游戏存档数据模型
class GameSave {
  final String gameMode; // 'classic' 或 'master'
  final int difficulty;
  final int elapsedSeconds;
  final int currentScore;
  final DateTime saveTime;
  final String imageSource;
  final List<int?> placedPiecesIds; // 已放置拼图块的ID列表
  final List<int> availablePiecesIds; // 可用拼图块的ID列表

  // Master模式专用数据
  final List<MasterPieceData>? masterPieces;

  GameSave({
    required this.gameMode,
    required this.difficulty,
    required this.elapsedSeconds,
    required this.currentScore,
    required this.saveTime,
    required this.imageSource,
    required this.placedPiecesIds,
    required this.availablePiecesIds,
    this.masterPieces,
  });

  Map<String, dynamic> toJson() {
    return {
      'gameMode': gameMode,
      'difficulty': difficulty,
      'elapsedSeconds': elapsedSeconds,
      'currentScore': currentScore,
      'saveTime': saveTime.toIso8601String(),
      'imageSource': imageSource,
      'placedPiecesIds': placedPiecesIds,
      'availablePiecesIds': availablePiecesIds,
      'masterPieces': masterPieces?.map((p) => p.toJson()).toList(),
    };
  }

  factory GameSave.fromJson(Map<String, dynamic> json) {
    return GameSave(
      gameMode: json['gameMode'],
      difficulty: json['difficulty'],
      elapsedSeconds: json['elapsedSeconds'],
      currentScore: json['currentScore'],
      saveTime: DateTime.parse(json['saveTime']),
      imageSource: json['imageSource'],
      placedPiecesIds: List<int?>.from(json['placedPiecesIds']),
      availablePiecesIds: List<int>.from(json['availablePiecesIds']),
      masterPieces: json['masterPieces']
          ?.map<MasterPieceData>((p) => MasterPieceData.fromJson(p))
          .toList(),
    );
  }
}

// Master模式拼图块数据
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

// 大师模式存档数据结构
class MasterModeSaveData {
  final int targetX;
  final int targetY;
  final double pieceSize;
  final int gridSize;
  final List<Offset> targetPositions;
  final bool isCloseMatch;
  final double matchThreshold;

  MasterModeSaveData({
    required this.targetX,
    required this.targetY,
    required this.pieceSize,
    required this.gridSize,
    required this.targetPositions,
    required this.isCloseMatch,
    required this.matchThreshold,
  });

  Map<String, dynamic> toJson() => {
        'targetX': targetX,
        'targetY': targetY,
        'pieceSize': pieceSize,
        'gridSize': gridSize,
        'targetPositions':
            targetPositions.map((pos) => {'x': pos.dx, 'y': pos.dy}).toList(),
        'isCloseMatch': isCloseMatch,
        'matchThreshold': matchThreshold,
      };

  factory MasterModeSaveData.fromJson(Map<String, dynamic> json) {
    return MasterModeSaveData(
      targetX: json['targetX'] ?? 0,
      targetY: json['targetY'] ?? 0,
      pieceSize: json['pieceSize']?.toDouble() ?? 100.0,
      gridSize: json['gridSize'] ?? 3,
      targetPositions: (json['targetPositions'] as List?)
              ?.map((pos) => Offset(
                  pos['x']?.toDouble() ?? 0.0, pos['y']?.toDouble() ?? 0.0))
              .toList() ??
          [],
      isCloseMatch: json['isCloseMatch'] ?? false,
      matchThreshold: json['matchThreshold']?.toDouble() ?? 50.0,
    );
  }
}

class GameSaveService {
  static const String baseUrl = 'http://localhost:5000/api'; // Adjust if needed
  static final AuthService _authService = AuthService();

  static Future<void> saveGame(
      String gameMode, String difficulty, Map<String, dynamic> saveData) async {
    final token = _authService.token;
    final response = await http.post(
      Uri.parse('$baseUrl/save-game'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'gameMode': gameMode,
        'difficulty': difficulty,
        ...saveData,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to save game: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>?> loadGame(
      String gameMode, String difficulty) async {
    final token = _authService.token;
    final response = await http.get(
      Uri.parse('$baseUrl/load-save?gameMode=$gameMode&difficulty=$difficulty'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null; // No save found
    } else {
      throw Exception('Failed to load game: ${response.body}');
    }
  }

  static Future<void> deleteGame(String gameMode, String difficulty) async {
    final token = _authService.token;
    final response = await http.delete(
      Uri.parse(
          '$baseUrl/delete-save?gameMode=$gameMode&difficulty=$difficulty'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete game: ${response.body}');
    }
  }

  static Future<bool> hasSave(String gameMode, String difficulty) async {
    final token = _authService.token;
    final response = await http.get(
      Uri.parse('$baseUrl/load-save?gameMode=$gameMode&difficulty=$difficulty'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode == 200;
  }

  // 格式化存档时间显示
  static String formatSaveTime(DateTime saveTime) {
    final now = DateTime.now();
    final difference = now.difference(saveTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  // 格式化游戏时长显示
  static String formatGameTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainingSeconds = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainingSeconds';
  }

  // 获取难度文本
  static String getDifficultyText(int difficulty) {
    switch (difficulty) {
      case 1:
        return '简单';
      case 2:
        return '中等';
      case 3:
        return '困难';
      default:
        return '未知';
    }
  }

  // 获取游戏模式文本
  static String getGameModeText(String gameMode) {
    switch (gameMode) {
      case 'classic':
        return '经典模式';
      case 'master':
        return '大师模式';
      default:
        return '未知模式';
    }
  }
}
