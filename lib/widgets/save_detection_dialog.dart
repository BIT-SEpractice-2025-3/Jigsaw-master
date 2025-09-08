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
    print("asssssssssssssssssssssss");
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.save, color: Colors.blue, size: 28),
              SizedBox(width: 8),
              Text('发现游戏存档'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('检测到您有未完成的游戏进度：'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.games,
                            size: 16, color: Colors.blue.shade700),
                        SizedBox(width: 6),
                        Text(
                          '游戏模式: ${gameMode == 'classic' ? '经典模式' : '大师模式'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star,
                            size: 16, color: Colors.amber.shade700),
                        SizedBox(width: 6),
                        Text(
                          '难度等级: $difficulty',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.amber.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                '是否要继续之前的游戏进度？',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // 不加载存档
              },
              child: Text('开始新游戏'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true); // 加载存档
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restore, size: 16),
                  SizedBox(width: 6),
                  Text('继续游戏'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // 快速存档信息预览
  static Widget buildSaveIndicator({
    required String gameMode,
    required String difficulty,
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
