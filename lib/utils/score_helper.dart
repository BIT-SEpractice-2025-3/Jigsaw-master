import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/achievements.dart';

// 游戏结束后的分数提交工具类
class ScoreSubmissionHelper {
  static final AuthService _authService = AuthService();

  // 提交分数并显示结果
  static Future<void> submitGameScore({
    required BuildContext context,
    required int score,
    required int timeInSeconds,
    required String difficulty,
  }) async {
    if (!_authService.isLoggedIn) {
      _showLoginPrompt(context);
      return;
    }

    try {
      // 显示加载对话框
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在提交分数...'),
            ],
          ),
        ),
      );

      await _authService.submitScore(score, timeInSeconds, difficulty);

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 检查成就完成情况并显示弹窗
      await AchievementsPage.checkAndUnlockAchievements(context);

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('分数提交成功！得分: $score'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: '查看排行榜',
            textColor: Colors.white,
            onPressed: () {
              // 这里可以导航到排行榜页面
              Navigator.of(context).pushNamed('/leaderboard');
            },
          ),
        ),
      );
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();

      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('分数提交失败: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: '重试',
            textColor: Colors.white,
            onPressed: () {
              // 重新调用提交方法
              submitGameScore(
                context: context,
                score: score,
                timeInSeconds: timeInSeconds,
                difficulty: difficulty,
              );
            },
          ),
        ),
      );
    }
  }

  // 新增：自动提交分数选项
  static Future<void> submitGameScoreAuto({
    required BuildContext context,
    required int score,
    required int timeInSeconds,
    required String difficulty,
    required bool autoSubmit,
  }) async {
    if (!autoSubmit) return;

    if (!_authService.isLoggedIn) {
      // 如果未登录，显示提示但不中断游戏流程
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('请先登录以保存游戏分数'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: '去登录',
            textColor: Colors.white,
            onPressed: () {
              // 导航到登录页面
              Navigator.of(context).pushNamed('/login');
            },
          ),
        ),
      );
      return;
    }

    try {
      // 静默提交分数（不显示加载对话框）
      await _authService.submitScore(score, timeInSeconds, difficulty);

      // 检查成就完成情况但不显示弹窗（静默模式）
      await AchievementsPage.checkAndUnlockAchievements(context,
          showDialog: false);

      // 显示简短的成功提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('分数已自动保存: $score'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // 静默失败，不打扰用户游戏体验
      print('自动分数提交失败: $e');
    }
  }

  // 显示登录提示
  static void _showLoginPrompt(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要登录'),
        content: const Text('请先登录以保存您的游戏分数'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 这里可以导航到登录页面
            },
            child: const Text('去登录'),
          ),
        ],
      ),
    );
  }

  // 格式化时间显示
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // 计算分数（示例算法）
  static int calculateScore({
    required int timeInSeconds,
    required String difficulty,
    required int moves,
  }) {
    int baseScore = 10000;

    // 根据难度调整基础分数
    switch (difficulty) {
      case 'easy':
        baseScore = 5000;
        break;
      case 'medium':
        baseScore = 10000;
        break;
      case 'hard':
        baseScore = 20000;
        break;
      case 'master':
        baseScore = 40000;
        break;
    }

    // 时间惩罚（每秒减少10分）
    int timePenalty = timeInSeconds * 10;

    // 移动惩罚（每步多余移动减少5分）
    int movePenalty = moves > 100 ? (moves - 100) * 5 : 0;

    int finalScore = baseScore - timePenalty - movePenalty;
    return finalScore > 0 ? finalScore : 100; // 最低100分
  }
}
