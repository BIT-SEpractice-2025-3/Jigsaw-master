import 'package:flutter/material.dart';
import '../services/auth_service_simple.dart';

class AuthDebugPage extends StatefulWidget {
  const AuthDebugPage({Key? key}) : super(key: key);

  @override
  State<AuthDebugPage> createState() => _AuthDebugPageState();
}

class _AuthDebugPageState extends State<AuthDebugPage> {
  final AuthService _authService = AuthService();
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _updateDebugInfo();
  }

  void _updateDebugInfo() {
    setState(() {
      _debugInfo = '''
登录状态: ${_authService.isLoggedIn}
用户数据: ${_authService.currentUser}
当前时间: ${DateTime.now()}
      ''';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('认证调试'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '认证状态调试信息',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _debugInfo,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _updateDebugInfo();
                  },
                  child: const Text('刷新状态'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    await _authService.loadAuthData();
                    _updateDebugInfo();
                  },
                  child: const Text('重新加载'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_authService.isLoggedIn)
              ElevatedButton(
                onPressed: () async {
                  try {
                    final leaderboard = await _authService.getLeaderboard();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('获取到 ${leaderboard.length} 条排行榜数据'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('获取排行榜失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('测试排行榜API'),
              ),
          ],
        ),
      ),
    );
  }
}
