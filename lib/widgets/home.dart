import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'dart:async'; // 添加Timer支持
import 'game_select.dart';
import 'ranking.dart'; // 使用ranking_new.dart
import 'diy.dart';
import 'login_page.dart';
import 'ai_image_generator.dart'; // 添加AI图片生成页面的导入
import '../services/auth_service.dart'; // 使用auth_service_simple.dart
import '../pages/friends_page.dart'; // <-- 1. 导入我们之后会创建的好友页面
import '../services/socket_service.dart'; // <-- 2. 导入Socket服务
import 'setting.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final SocketService _socketService = SocketService();
  bool _isUserBarExpanded = false;
  Timer? _collapseTimer;

  @override
  void initState() {
    super.initState();
    _loadAuthDataAndConnectSocket(); // <-- 4. 调用新的初始化方法
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  // 替换原来的 _loadAuthData 方法
  Future<void> _loadAuthDataAndConnectSocket() async {
    await _authService.loadAuthData();
    // 检查组件是否还在树上，这是一个好习惯
    if (mounted && _authService.isLoggedIn) {
      // 登录成功后，使用token连接Socket并进行认证
      _socketService.connectAndListen(_authService.token!);
    }
    if (mounted) {
      setState(() {});
    }
  }

  // 替换原来的 _refreshAuthState 方法
  Future<void> _refreshAuthState() async {
    await _loadAuthDataAndConnectSocket(); // 刷新时也需要重新连接socket
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: SizedBox(
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              // 背景装饰 - 拼图元素
              _buildBackgroundPuzzleElements(context),

              // 右上角设置图标
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.settings,
                    color: Color(0xFF6A5ACD),
                    size: 28,
                  ),
                  tooltip: '设置',
                ),
              ),

              // 右上角排行榜图标
              Positioned(
                top: 40,
                right: 60,
                child: IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RankingPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.leaderboard_rounded,
                    color: Color(0xFFE91E63),
                    size: 28,
                  ),
                  tooltip: '排行榜',
                ),
              ),

              // 主要内容
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 新增：用户状态栏
                    // 移除，现在在左上角
                    const SizedBox(height: 130),

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
                        SizedBox(height: 10),
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
                                  builder: (context) =>
                                      const GameSelectionPage()),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMenuButton(
                          context: context,
                          icon: Icons.people_alt_rounded,
                          title: '好友对战',
                          subtitle: '邀请好友一决高下',
                          color: const Color(0xFF1E88E5), // 蓝色
                          onPressed: () {
                            if (_authService.isLoggedIn) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const FriendsPage()),
                              );
                            } else {
                              // 提示用户需要登录
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text('请先登录以使用好友功能'),
                                behavior: SnackBarBehavior.floating,
                              ));
                              // 可选：跳转到登录页
                              // Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
                            }
                          },
                        ),
                        // ▲▲▲ 添加结束 ▲▲▲
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
                          icon: Icons.auto_awesome,
                          title: 'AI生成拼图图片',
                          subtitle: '使用AI生成自定义图片',
                          color: Colors.teal,
                          onPressed: () {
                            // 跳转到AI图片生成页面
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AIImageGeneratorPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Spacer(), // 添加Spacer以推到底部
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

              // 左上角用户状态图标/栏
              Positioned(
                top: 40,
                left: 20,
                child: _buildUserStatusBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleUserBar() {
    setState(() {
      _isUserBarExpanded = !_isUserBarExpanded;
    });

    // 取消之前的定时器
    _collapseTimer?.cancel();

    // 如果展开状态，设置5秒后自动收起
    if (_isUserBarExpanded) {
      _collapseTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isUserBarExpanded = false;
          });
        }
      });
    }
  }

  // 新增：用户状态栏
  Widget _buildUserStatusBar() {
    if (!_isUserBarExpanded) {
      // 收起状态：只显示图标
      return GestureDetector(
        onTap: _toggleUserBar,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
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
          child: Icon(
            _authService.isLoggedIn ? Icons.person : Icons.person_outline,
            color: const Color(0xFF6A5ACD),
            size: 24,
          ),
        ),
      );
    }

    // 展开状态：显示完整的用户状态栏
    return GestureDetector(
      onTap: _toggleUserBar,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
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
          mainAxisSize: MainAxisSize.min,
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
                      mainAxisSize: MainAxisSize.min,
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
                  _socketService.dispose(); // <-- 6. 用户登出时，断开Socket连接
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
