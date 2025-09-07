// 分数提交测试页面
// 用于测试分数提交功能

import 'package:flutter/material.dart';
import '../services/auth_service_simple.dart';
import '../utils/score_helper.dart';

class ScoreTestPage extends StatefulWidget {
  const ScoreTestPage({Key? key}) : super(key: key);

  @override
  _ScoreTestPageState createState() => _ScoreTestPageState();
}

class _ScoreTestPageState extends State<ScoreTestPage> {
  final AuthService _authService = AuthService();
  final TextEditingController _scoreController = TextEditingController(text: '1000');
  final TextEditingController _timeController = TextEditingController(text: '120');
  String _difficulty = 'medium';
  bool _autoSubmit = false;

  @override
  void dispose() {
    _scoreController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分数提交测试'),
        backgroundColor: Colors.deepPurple.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 登录状态
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _authService.isLoggedIn ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _authService.isLoggedIn ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _authService.isLoggedIn ? Icons.check_circle : Icons.error,
                    color: _authService.isLoggedIn ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _authService.isLoggedIn
                        ? '已登录: ${_authService.currentUser?['username']}'
                        : '未登录，请先登录',
                    style: TextStyle(
                      color: _authService.isLoggedIn ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 分数输入
            TextField(
              controller: _scoreController,
              decoration: const InputDecoration(
                labelText: '分数',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // 时间输入
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: '用时（秒）',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // 难度选择
            DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: const InputDecoration(
                labelText: '难度',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('简单')),
                DropdownMenuItem(value: 'medium', child: Text('中等')),
                DropdownMenuItem(value: 'hard', child: Text('困难')),
              ],
              onChanged: (value) {
                setState(() {
                  _difficulty = value ?? 'medium';
                });
              },
            ),

            const SizedBox(height: 16),

            // 自动提交选项
            SwitchListTile(
              title: const Text('自动提交'),
              subtitle: const Text('模拟自动提交功能'),
              value: _autoSubmit,
              onChanged: (value) {
                setState(() {
                  _autoSubmit = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // 测试按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _authService.isLoggedIn ? _testManualSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('手动提交测试'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _authService.isLoggedIn ? _testAutoSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('自动提交测试'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 导航到登录页面
            if (!_authService.isLoggedIn)
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('去登录'),
                ),
              ),

            const SizedBox(height: 24),

            // 说明文本
            const Text(
              '测试说明：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '1. 确保已登录账户\n'
              '2. 输入测试分数和时间\n'
              '3. 选择难度等级\n'
              '4. 点击测试按钮\n'
              '5. 查看提交结果反馈',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _testManualSubmit() {
    final score = int.tryParse(_scoreController.text) ?? 0;
    final time = int.tryParse(_timeController.text) ?? 0;

    ScoreSubmissionHelper.submitGameScore(
      context: context,
      score: score,
      timeInSeconds: time,
      difficulty: _difficulty,
    );
  }

  void _testAutoSubmit() {
    final score = int.tryParse(_scoreController.text) ?? 0;
    final time = int.tryParse(_timeController.text) ?? 0;

    ScoreSubmissionHelper.submitGameScoreAuto(
      context: context,
      score: score,
      timeInSeconds: time,
      difficulty: _difficulty,
      autoSubmit: true,
    );
  }
}