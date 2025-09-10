//难度选择
//->游戏界面
//->主页

import 'package:flutter/material.dart';
import 'puzzle.dart';
import 'puzzle_master.dart';
import 'ai_image_generator.dart';

class GameSelectionPage extends StatelessWidget {
  final String? imagePath; // 添加图片路径参数
  const GameSelectionPage({super.key, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 使 AppBar 真正透明并覆盖在页面顶部
      extendBodyBehindAppBar: true,
      // 与其他页面保持一致：顶部显示返回按钮
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          _buildBackgroundPuzzleElements(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Column(
                  children: [
                    Icon(
                      Icons.auto_awesome_mosaic_rounded,
                      size: 70,
                      color: Color(0xFF6A5ACD),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '选择难度',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2B55),
                        letterSpacing: 1.2,
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
                      '请选择适合你的挑战级别',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
                _buildMenuButton(
                  context: context,
                  icon: Icons.grid_3x3,
                  title: '简单模式',
                  subtitle: '3x3 网格，轻松上手',
                  color: const Color(0xFF6A5ACD),
                  onPressed: () {
                    _navigateToPuzzle(context, 1);
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context: context,
                  icon: Icons.grid_4x4,
                  title: '中等模式',
                  subtitle: '4x4 网格，挑战思维',
                  color: const Color(0xFFE91E63),
                  onPressed: () {
                    _navigateToPuzzle(context, 2);
                  },
                ),
                const SizedBox(height: 16),
                _buildMenuButton(
                  context: context,
                  icon: Icons.grid_on,
                  title: '困难模式',
                  subtitle: '5x5 网格，终极考验',
                  color: const Color(0xFFFF9800),
                  onPressed: () {
                    _navigateToPuzzle(context, 3);
                  },
                ),
                const SizedBox(height: 20),
                // 将原来的“退出”按钮改为进入大师模式（master mode）
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      // 跳转到大师模式页面（请确保 assets/default.jpg 已配置在项目中）
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PuzzleMasterPage(
                            imageSource: imagePath,
                            difficulty: 4,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    label: const Text(
                      '进入大师模式',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToPuzzle(BuildContext context, int difficulty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PuzzlePage(
          difficulty: difficulty,
          imagePath: imagePath, // 传递图片路径
        ),
      ),
    );
  }

  Widget _buildBackgroundPuzzleElements(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
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
        Positioned(
          top: -30,
          left: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x4D6A5ACD), // 使用带透明度的颜色值
            size: 150,
            rotation: 0.2,
          ),
        ),
        Positioned(
          top: 50,
          right: -40,
          child: _buildPuzzleDecoration(
            color: const Color(0x4DE91E63),
            size: 120,
            rotation: -0.3,
          ),
        ),
        Positioned(
          bottom: 80,
          left: -50,
          child: _buildPuzzleDecoration(
            color: const Color(0x4DFF9800),
            size: 130,
            rotation: 0.7,
          ),
        ),
        Positioned(
          bottom: -40,
          right: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x4D4CAF50),
            size: 160,
            rotation: -0.5,
          ),
        ),
        Positioned(
          top: screenSize.height * 0.3,
          left: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x336A5ACD),
            size: 70,
            rotation: 0.1,
          ),
        ),
        Positioned(
          bottom: screenSize.height * 0.3,
          right: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x33FF9800),
            size: 60,
            rotation: -0.2,
          ),
        ),
      ],
    );
  }

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

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 4,
        shadowColor: Color.fromRGBO(color.red, color.green, color.blue, 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Color.fromRGBO(color.red, color.green, color.blue, 0.2),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ).copyWith(
        backgroundColor: MaterialStateProperty.resolveWith<Color>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.hovered)) {
              return Color.fromRGBO(
                  color.red, color.green, color.blue, 0.1); // 悬停时变深
            }
            return Colors.white; // 默认颜色
          },
        ),
        elevation: MaterialStateProperty.resolveWith<double>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.hovered)) {
              return 0; // 悬停时增加阴影
            }
            return 4; // 默认阴影
          },
        ),
      ),
      onPressed: onPressed,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Color.fromRGBO(color.red, color.green, color.blue, 0.15),
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
            color: Color.fromRGBO(color.red, color.green, color.blue, 0.1),
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
    );
  }
}

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

    _drawPuzzleTab(canvas, center, radius, 0, paint);
    _drawPuzzleTab(canvas, center, radius, 1, paint);
    _drawPuzzleTab(canvas, center, radius, 2, paint);
    _drawPuzzleTab(canvas, center, radius, 3, paint);
  }

  void _drawPuzzleTab(
      Canvas canvas, Offset center, double radius, int side, Paint paint) {
    final path = Path();
    final tabWidth = radius / 2;

    switch (side) {
      case 0:
        path.moveTo(center.dx - tabWidth, center.dy - radius);
        path.quadraticBezierTo(
          center.dx,
          center.dy - radius - tabWidth,
          center.dx + tabWidth,
          center.dy - radius,
        );
        break;
      case 1:
        path.moveTo(center.dx + radius, center.dy - tabWidth);
        path.quadraticBezierTo(
          center.dx + radius + tabWidth,
          center.dy,
          center.dx + radius,
          center.dy + tabWidth,
        );
        break;
      case 2:
        path.moveTo(center.dx + tabWidth, center.dy + radius);
        path.quadraticBezierTo(
          center.dx,
          center.dy + radius + tabWidth,
          center.dx - tabWidth,
          center.dy + radius,
        );
        break;
      case 3:
        path.moveTo(center.dx - radius, center.dy + tabWidth);
        path.quadraticBezierTo(
          center.dx - radius - tabWidth,
          center.dy,
          center.dx - radius,
          center.dy - tabWidth,
        );
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
