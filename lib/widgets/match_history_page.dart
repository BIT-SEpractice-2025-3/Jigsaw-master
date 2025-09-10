import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/match_history.dart';
import '../services/friend_service.dart';

class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  final FriendService _friendService = FriendService();
  late Future<List<MatchHistory>> _matchHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _matchHistoryFuture = _friendService.getMatchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('对战记录'),
        backgroundColor: Colors.white.withOpacity(0.8),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 背景装饰 - 拼图元素
          _buildBackgroundPuzzleElements(context),
          // 主要内容
          RefreshIndicator(
            onRefresh: _loadHistory,
            child: FutureBuilder<List<MatchHistory>>(
              future: _matchHistoryFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('加载失败: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('你还没有任何对战记录'));
                }

                final history = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: history.length,
                  itemBuilder: (context, index) {
                    final match = history[index];
                    final isWin = match.result == '胜利';
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isWin
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isWin
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              isWin
                                  ? Icons.emoji_events_rounded
                                  : Icons.sentiment_dissatisfied_rounded,
                              color: isWin
                                  ? Colors.green.shade800
                                  : Colors.red.shade800,
                            ),
                          ),
                          title: Text(
                            'vs ${match.opponentUsername}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '难度: ${match.difficulty} - ${DateFormat('yyyy-MM-dd HH:mm').format(match.completedAt)}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          trailing: Text(
                            match.result,
                            style: TextStyle(
                              color: isWin ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
}

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
