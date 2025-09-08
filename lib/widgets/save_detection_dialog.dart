// 存档检测对话框组件
// 用于在开始游戏前检查是否有历史存档

import 'package:flutter/material.dart';
import '../services/game_save_service.dart';

class SaveDetectionDialog {
  // 显示存档检测对话框
  static Future<bool?> showSaveDialog({
    required BuildContext context,
    required String gameMode,
    required int difficulty,
  }) async {
    // 检查是否有存档
    final hasSave = await GameSaveService.hasSave(gameMode, difficulty);

    if (!hasSave) {
      return null; // 没有存档，直接开始新游戏
    }

    // 获取存档信息
    final gameSave = await GameSaveService.loadGame(gameMode, difficulty);
    if (gameSave == null) {
      return null; // 存档数据无效
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.save_alt, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('发现历史存档'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到您有未完成的游戏，是否继续上次的进度？'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.gamepad,
                            color: Colors.blue.shade600, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '${GameSaveService.getGameModeText(gameSave.gameMode)} - ${GameSaveService.getDifficultyText(gameSave.difficulty)}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            color: Colors.blue.shade600, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '游戏时长: ${GameSaveService.formatGameTime(gameSave.elapsedSeconds)}',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.blue.shade600, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '当前分数: ${gameSave.currentScore}',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            color: Colors.blue.shade600, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '保存时间: ${GameSaveService.formatSaveTime(gameSave.saveTime)}',
                          style: TextStyle(color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.orange.shade600, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '选择"新游戏"将删除当前存档',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: Text('新游戏'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('继续游戏'),
            ),
          ],
        );
      },
    );
  }

  // 快速存档信息预览
  static Widget buildSaveIndicator({
    required String gameMode,
    required int difficulty,
  }) {
    return FutureBuilder<bool>(
      future: GameSaveService.hasSave(gameMode, difficulty),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.save_alt, size: 12, color: Colors.green.shade700),
                SizedBox(width: 2),
                Text(
                  '有存档',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }
        return SizedBox.shrink();
      },
    );
  }
}
