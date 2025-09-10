// lib/pages/friends_page.dart (完整代码)

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../services/friend_service.dart';
import '../services/socket_service.dart';
import 'match_history_page.dart'; // <-- 1. 导入新页面

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FriendService _friendService = FriendService();
  final SocketService _socketService = SocketService();

  // 用于强制刷新列表的键
  ValueNotifier<int> friendsListVersion = ValueNotifier(0);
  ValueNotifier<int> requestsListVersion = ValueNotifier(0);

  late StreamSubscription _friendStatusSubscription;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // 监听好友上下线事件，并刷新好友列表
    _friendStatusSubscription = _socketService.onFriendStatusUpdate.listen((_) {
      friendsListVersion.value++;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendStatusSubscription.cancel();
    super.dispose();
  }

  void _refreshAll() {
    friendsListVersion.value++;
    requestsListVersion.value++;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('好友对战中心'),
        // ▼▼▼ 2. 在这里添加按钮 ▼▼▼
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '对战记录',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const MatchHistoryPage()),
              );
            },
          ),
        ],
        // ▲▲▲ 修改结束 ▲▲▲
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_rounded), text: '我的好友'),
            Tab(icon: Icon(Icons.person_add_alt_1_rounded), text: '好友请求'),
            Tab(icon: Icon(Icons.search_rounded), text: '添加好友'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 背景装饰 - 拼图元素
          _buildBackgroundPuzzleElements(context),
          // 主要内容
          TabBarView(
            controller: _tabController,
            children: [
              _buildFriendsList(),
              _buildRequestsList(),
              _buildAddFriendTab(),
            ],
          ),
        ],
      ),
    );
  }

  // --- Tab 1: 我的好友列表 ---
  Widget _buildFriendsList() {
    return ValueListenableBuilder<int>(
        valueListenable: friendsListVersion,
        builder: (context, version, child) {
          return FutureBuilder<List<Friend>>(
            key: ValueKey(version), // 使用version作为key来触发刷新
            future: _friendService.getFriends(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('加载失败: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('你还没有好友，快去添加吧！'));
              }
              final friends = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async => _refreshAll(),
                child: ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: friend.statusColor.withOpacity(0.2),
                          child: Text(friend.username[0].toUpperCase()),
                        ),
                        title: Text(friend.username),
                        subtitle: Text(friend.status,
                            style: TextStyle(color: friend.statusColor)),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(Icons.gamepad_rounded, size: 16),
                          label: const Text('邀请'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: friend.status == 'online'
                              ? () => _showInviteDialog(friend)
                              : null, // 如果不在线，按钮不可用
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        });
  }

  // --- Tab 2: 好友请求列表 ---
  Widget _buildRequestsList() {
    return ValueListenableBuilder<int>(
        valueListenable: requestsListVersion,
        builder: (context, version, child) {
          return FutureBuilder<List<FriendRequest>>(
            key: ValueKey(version),
            future: _friendService.getFriendRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('没有待处理的好友请求'));
              }
              final requests = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async => _refreshAll(),
                child: ListView.builder(
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(request.username[0].toUpperCase())),
                        title: Text(request.username),
                        subtitle: const Text('向你发送了好友请求'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              onPressed: () => _respondToRequest(
                                  request.friendshipId, 'accept'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _respondToRequest(
                                  request.friendshipId, 'decline'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        });
  }

  // --- Tab 3: 添加好友 ---
  Widget _buildAddFriendTab() {
    final TextEditingController _searchController = TextEditingController();
    final ValueNotifier<List<SearchedUser>> _searchResults = ValueNotifier([]);
    final ValueNotifier<bool> _isLoading = ValueNotifier(false);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: '按用户名搜索',
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: () async {
                  final query = _searchController.text.trim();
                  if (query.length < 2) return;
                  _isLoading.value = true;
                  try {
                    _searchResults.value =
                        await _friendService.searchUsers(query);
                  } finally {
                    _isLoading.value = false;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: _isLoading,
              builder: (context, isLoading, child) {
                if (isLoading)
                  return const Center(child: CircularProgressIndicator());
                return ValueListenableBuilder<List<SearchedUser>>(
                  valueListenable: _searchResults,
                  builder: (context, results, child) {
                    if (results.isEmpty)
                      return const Center(child: Text('输入关键词进行搜索'));
                    return ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final user = results[index];
                        return ListTile(
                          title: Text(user.username),
                          trailing: _buildAddFriendButton(user),
                        );
                      },
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

  void _showInviteDialog(Friend friend) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        // 使用 dialogContext 避免歧义
        return AlertDialog(
          title: Text('邀请 ${friend.username} 对战'),
          content: const Text('选择一个难度开始对战。\n图片将使用默认图片。'),
          actionsAlignment: MainAxisAlignment.spaceEvenly, // 让按钮分布更均匀
          actions: <Widget>[
            // --- 修改部分开始 ---
            TextButton(
              onPressed: () =>
                  _sendInvite(friend.id, 'easy'), // 修改 '1' 为 'easy'
              child: const Text('简单'),
            ),
            TextButton(
              onPressed: () =>
                  _sendInvite(friend.id, 'medium'), // 修改 '2' 为 'medium'
              child: const Text('中等'),
            ),
            TextButton(
              onPressed: () =>
                  _sendInvite(friend.id, 'hard'), // 修改 '3' 为 'hard'
              child: const Text('困难'),
            ),
          ],
        );
      },
    );
  }

  void _sendInvite(int friendId, String difficulty) {
    // 确保 dialogContext.mounted 检查 (虽然在这个简单场景下不是必须的，但是个好习惯)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(); // 关闭选择难度的对话框
    }

    _socketService.sendInvite(
        friendId, difficulty, 'assets/images/default_puzzle.jpg');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('邀请已发送！'), backgroundColor: Colors.green),
    );
  }

  Future<void> _respondToRequest(int friendshipId, String action) async {
    try {
      await _friendService.respondToFriendRequest(friendshipId, action);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(action == 'accept' ? '好友已添加' : '已拒绝请求'),
            backgroundColor: Colors.green),
      );
      _refreshAll();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAddFriendButton(SearchedUser user) {
    if (user.status == 'accepted') {
      return const Chip(label: Text('已是好友'), backgroundColor: Colors.grey);
    }
    if (user.status == 'pending') {
      return const Chip(label: Text('请求已发送'));
    }
    return ElevatedButton(
      child: const Text('添加'),
      onPressed: () async {
        try {
          await _friendService.sendFriendRequest(user.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('好友请求已发送！'), backgroundColor: Colors.green),
          );
          // 可选：刷新搜索结果以更新按钮状态
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('操作失败: $e'), backgroundColor: Colors.red),
          );
        }
      },
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
