import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'game_select.dart';
import 'ranking.dart'; // 使用ranking_new.dart
import 'diy.dart';
import 'login_page.dart';
import 'setting.dart';
import '../services/auth_service.dart'; // 使用auth_service_simple.dart

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadAuthData();
  }

  Future<void> _loadAuthData() async {
    await _authService.loadAuthData();
    if (mounted) {
      setState(() {});
    }
  }

  // 刷新用户状态
  Future<void> _refreshAuthState() async {
    await _authService.loadAuthData();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // 背景装饰 - 拼图元素
          _buildBackgroundPuzzleElements(context),

          // 主要内容
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 新增：用户状态栏
                _buildUserStatusBar(),
                const SizedBox(height: 20),

                // 应用标题和图标
                const Column(
                  children: [
                    Icon(
                      Icons.extension_rounded,
                      size: 80,
                      color: Color(0xFF6A5ACD),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '拼图大师',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2B55),
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            blurRadius: 4.0,
                            color: Colors.black12,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '挑战你的空间思维与逻辑能力',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),

                // 功能按钮区域
                Column(
                  children: [
                    _buildMenuButton(
                      context: context,
                      icon: Icons.play_circle_fill_rounded,
                      title: '开始游戏',
                      subtitle: '选择难度开始挑战',
                      color: const Color(0xFF6A5ACD),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const GameSelectionPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      icon: Icons.leaderboard_rounded,
                      title: '排行榜',
                      subtitle: '查看最高分数记录',
                      color: const Color(0xFFE91E63),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RankingPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      icon: Icons.photo_library_rounded,
                      title: '自定义拼图',
                      subtitle: '使用自己的图片创建拼图',
                      color: const Color(0xFFFF9800),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const DiyPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildMenuButton(
                      context: context,
                      icon: Icons.settings,
                      title: '设置',
                      subtitle: '设置游戏应用',
                      color: Colors.grey,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // 底部版权信息
                const Column(
                  children: [
                    Text(
                      '北京理工大学软件工程学院',
                      style: TextStyle(
                        color: Color(0xFF6A5ACD),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '软件工程综合实践 · 2023级',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 新增：用户状态栏
  Widget _buildUserStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6A5ACD).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6A5ACD).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _authService.isLoggedIn ? Icons.person : Icons.person_outline,
              color: const Color(0xFF6A5ACD),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _authService.isLoggedIn
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '欢迎回来！',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _authService.currentUser?['username'] ?? '用户',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2B55),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    '未登录 - 点击登录获得更好体验',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2D2B55),
                    ),
                  ),
          ),
          if (_authService.isLoggedIn)
            TextButton(
              onPressed: () async {
                await _authService.logout();
                _refreshAuthState();
              },
              child: const Text(
                '退出',
                style: TextStyle(
                  color: Color(0xFF6A5ACD),
                  fontSize: 12,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                ).then((_) {
                  // 登录后刷新状态
                  _refreshAuthState();
                });
              },
              child: const Text(
                '登录',
                style: TextStyle(
                  color: Color(0xFF6A5ACD),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 构建背景拼图元素
  Widget _buildBackgroundPuzzleElements(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 背景渐变
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3F4F8),
                Color(0xFFE8EAF6),
                Color(0xFFF3F4F8),
              ],
            ),
          ),
        ),

        // 左上角拼图元素
        Positioned(
          top: -30,
          left: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x306A5ACD),
            size: 150,
            rotation: 0.2,
          ),
        ),

        // 右上角拼图元素
        Positioned(
          top: 50,
          right: -40,
          child: _buildPuzzleDecoration(
            color: const Color(0x30E91E63),
            size: 120,
            rotation: -0.3,
          ),
        ),

        // 左下角拼图元素
        Positioned(
          bottom: 80,
          left: -50,
          child: _buildPuzzleDecoration(
            color: const Color(0x30FF9800),
            size: 130,
            rotation: 0.7,
          ),
        ),

        // 右下角拼图元素
        Positioned(
          bottom: -40,
          right: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x304CAF50),
            size: 160,
            rotation: -0.5,
          ),
        ),

        // 中央装饰拼图元素
        Positioned(
          top: screenSize.height * 0.3,
          left: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x206A5ACD),
            size: 70,
            rotation: 0.1,
          ),
        ),

        Positioned(
          bottom: screenSize.height * 0.3,
          right: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x20FF9800),
            size: 60,
            rotation: -0.2,
          ),
        ),
      ],
    );
  }

  // 构建拼图装饰元素
  Widget _buildPuzzleDecoration({
    required Color color,
    required double size,
    double rotation = 0.0,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(
          painter: _PuzzlePiecePainter(color: color),
        ),
      ),
    );
  }

  // 构建菜单按钮
  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: ListTile(
          onTap: onPressed,
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          trailing: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 16,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }
}

// 拼图块绘制类
class _PuzzlePiecePainter extends CustomPainter {
  final Color color;

  _PuzzlePiecePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // 绘制拼图凹凸形状
    _drawPuzzleTab(canvas, center, radius, 0); // 上
    _drawPuzzleTab(canvas, center, radius, 1); // 右
    _drawPuzzleTab(canvas, center, radius, 2); // 下
    _drawPuzzleTab(canvas, center, radius, 3); // 左
  }

  void _drawPuzzleTab(Canvas canvas, Offset center, double radius, int side) {
    final path = Path();
    final tabWidth = radius / 2;

    switch (side) {
      case 0: // 上
        path.moveTo(center.dx - tabWidth, center.dy - radius);
        path.quadraticBezierTo(center.dx, center.dy - radius - tabWidth,
            center.dx + tabWidth, center.dy - radius);
        break;
      case 1: // 右
        path.moveTo(center.dx + radius, center.dy - tabWidth);
        path.quadraticBezierTo(center.dx + radius + tabWidth, center.dy,
            center.dx + radius, center.dy + tabWidth);
        break;
      case 2: // 下
        path.moveTo(center.dx + tabWidth, center.dy + radius);
        path.quadraticBezierTo(center.dx, center.dy + radius + tabWidth,
            center.dx - tabWidth, center.dy + radius);
        break;
      case 3: // 左
        path.moveTo(center.dx - radius, center.dy + tabWidth);
        path.quadraticBezierTo(center.dx - radius - tabWidth, center.dy,
            center.dx - radius, center.dy - tabWidth);
        break;
    }

    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
