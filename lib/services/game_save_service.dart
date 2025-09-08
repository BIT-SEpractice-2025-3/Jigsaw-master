// 游戏存档服务
// 负责保存和加载游戏进度

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';

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
  static const String _saveDirectory = 'game_saves';

  // 获取存档文件路径
  static String _getSaveFilePath(String gameMode, int difficulty) {
    return '$_saveDirectory/${gameMode}_difficulty_$difficulty.json';
  }

  // 检查是否有存档
  static Future<bool> hasSave(String gameMode, int difficulty) async {
    try {
      final filePath = _getSaveFilePath(gameMode, difficulty);
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      print('检查存档失败: $e');
      return false;
    }
  }

  // 保存游戏进度
  static Future<bool> saveGame({
    required String gameMode,
    required int difficulty,
    required int elapsedSeconds,
    required int currentScore,
    required String imageSource,
    required List<dynamic> placedPieces, // 改为dynamic避免类型依赖
    required List<dynamic> availablePieces,
    Map<String, dynamic>? masterData, // 改为Map存储master模式数据
  }) async {
    try {
      // 确保存档目录存在
      final directory = Directory(_saveDirectory);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 提取拼图块ID
      final placedPiecesIds = <int?>[];
      final availablePiecesIds = <int>[];

      for (final piece in placedPieces) {
        if (piece != null && piece.nodeId != null) {
          placedPiecesIds.add(piece.nodeId as int);
        } else {
          placedPiecesIds.add(null);
        }
      }

      for (final piece in availablePieces) {
        if (piece != null && piece.nodeId != null) {
          availablePiecesIds.add(piece.nodeId as int);
        }
      }

      // 创建存档数据
      final gameSave = GameSave(
        gameMode: gameMode,
        difficulty: difficulty,
        elapsedSeconds: elapsedSeconds,
        currentScore: currentScore,
        saveTime: DateTime.now(),
        imageSource: imageSource,
        placedPiecesIds: placedPiecesIds,
        availablePiecesIds: availablePiecesIds,
        masterPieces: masterData?['pieces']
            ?.map<MasterPieceData>((data) => MasterPieceData.fromJson(data))
            .toList(),
      );

      // 写入文件
      final filePath = _getSaveFilePath(gameMode, difficulty);
      final file = File(filePath);
      await file.writeAsString(jsonEncode(gameSave.toJson()));

      print('游戏存档保存成功: $filePath');
      return true;
    } catch (e) {
      print('保存游戏失败: $e');
      return false;
    }
  }

  // 加载游戏进度
  static Future<GameSave?> loadGame(String gameMode, int difficulty) async {
    try {
      final filePath = _getSaveFilePath(gameMode, difficulty);
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      print('游戏存档加载成功: $filePath');
      return GameSave.fromJson(jsonData);
    } catch (e) {
      print('加载游戏失败: $e');
      return null;
    }
  }

  // 删除存档
  static Future<bool> deleteSave(String gameMode, int difficulty) async {
    try {
      final filePath = _getSaveFilePath(gameMode, difficulty);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('游戏存档删除成功: $filePath');
      }

      return true;
    } catch (e) {
      print('删除存档失败: $e');
      return false;
    }
  }

  // 获取所有存档信息
  static Future<List<GameSave>> getAllSaves() async {
    try {
      final directory = Directory(_saveDirectory);
      if (!await directory.exists()) {
        return [];
      }

      final files = await directory.list().toList();
      final saves = <GameSave>[];

      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final jsonString = await file.readAsString();
            final jsonData = jsonDecode(jsonString);
            saves.add(GameSave.fromJson(jsonData));
          } catch (e) {
            print('读取存档文件失败: ${file.path}, $e');
          }
        }
      }

      return saves;
    } catch (e) {
      print('获取所有存档失败: $e');
      return [];
    }
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
