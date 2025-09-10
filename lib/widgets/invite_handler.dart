import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../widgets/puzzle_battle_page.dart'; // 我们之后会创建这个页面
import '../models/match.dart';

class InviteHandler extends StatefulWidget {
  final Widget child;
  const InviteHandler({super.key, required this.child});

  @override
  State<InviteHandler> createState() => _InviteHandlerState();
}

class _InviteHandlerState extends State<InviteHandler> {
  // 获取SocketService的单例
  final SocketService _socketService = SocketService();
  static bool _listenersInitialized = false;
  bool _isNavigatingToBattle = false;

  // StreamSubscription用于在widget销毁时取消监听，防止内存泄漏
  late StreamSubscription _newInviteSubscription;
  late StreamSubscription _matchStartedSubscription;
  late StreamSubscription _friendAcceptedSubscription;

  @override
  void initState() {
    super.initState();

    // ▼▼▼ 核心修正：只有在从未初始化过的情况下才注册监听器 ▼▼▼
    if (!_listenersInitialized) {
      // 开始监听来自SocketService的各个事件流
      _newInviteSubscription = _socketService.onNewInvite.listen(_showInviteDialog);
      _matchStartedSubscription = _socketService.onMatchStarted.listen(_navigateToBattlePage);
      _friendAcceptedSubscription = _socketService.onFriendRequestAccepted.listen(_showFriendAcceptedSnackbar);

      // 将标志位置为true，这样即使热重启也不会再次执行这里的代码
      _listenersInitialized = true;
      print("✅ InviteHandler listeners initialized for the first time.");
    } else {
      print("ℹ️ InviteHandler listeners already initialized, skipping registration.");
    }
  }

  /// 当收到新的对战邀请时，弹出一个全局对话框
  void _showInviteDialog(Map<String, dynamic> inviteData) {
    // 确保当前没有对话框时才显示新的
    if (ModalRoute.of(context)?.isCurrent != true) {
      Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false, // 用户必须做出选择
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.gamepad_rounded, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('对战邀请'),
            ],
          ),
          content: Text(
            '${inviteData['challenger_username']} 邀请你进行一场对战!',
            style: const TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('残忍拒绝'),
              onPressed: () {
                _socketService.respondToInvite(inviteData['match_id'], 'declined');
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('接受挑战!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _socketService.respondToInvite(inviteData['match_id'], 'accepted');
                Navigator.of(dialogContext).pop();
                // 等待服务器的 'match_started' 事件来自动导航
              },
            ),
          ],
        );
      },
    );
  }

  /// 当比赛正式开始时，导航到对战页面
  void _navigateToBattlePage(Match match) async {
    // ▼▼▼ 探针 #3：监听器被触发 ▼▼▼
    // print('>>> [INVITE_HANDLER] 探针 #3: _navigateToBattlePage 监听到事件，准备处理 Match ID ${match.id}。');
    if (_isNavigatingToBattle) {
      // print(">>> [INVITE_HANDLER] 警告: 导航锁已激活，阻止了重复导航。");
      return;
    }

    // 立即上锁
    _isNavigatingToBattle = true;
    // print(">>> [INVITE_HANDLER] 导航锁已激活。");

    // 检查组件是否仍然挂载在树上，这是一个非常重要的检查
    if (!mounted) {
      // print('>>> [INVITE_HANDLER] 警告: 组件已卸载(unmounted)，取消导航。');
      return;
    }

    // ▼▼▼ 探针 #4：检查导航守卫 ▼▼▼
    final currentRouteName = ModalRoute.of(context)?.settings.name;
    // print('>>> [INVITE_HANDLER] 探针 #4: 检查导航守卫。当前路由名称是: "$currentRouteName"。');

    if (currentRouteName != '/puzzle-battle') {
      // ▼▼▼ 探针 #5：导航守卫通过，准备执行导航 ▼▼▼
      // print('>>> [INVITE_HANDLER] 探针 #5: 导航守卫通过！正在执行 Navigator.push...');

      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/puzzle-battle'),
          builder: (context) => PuzzleBattlePage(match: match),
        ),
      );
      // print(">>> [INVITE_HANDLER] 从对战页面返回，导航锁已释放。");
      _isNavigatingToBattle = false;
    } else {
      // ▼▼▼ 探针 #6：导航守卫阻止了重复导航 ▼▼▼
      // print('>>> [INVITE_HANDLER] 探针 #6: 导航守卫生效，已在对战页面，阻止了重复导航。');
      _isNavigatingToBattle = false;
    }
  }

  /// 当好友请求被接受时，显示一个提示条
  void _showFriendAcceptedSnackbar(Map<String, dynamic> data) {
    final snackBar = SnackBar(
      content: Text('你和 ${data['username']} 已经成为好友了！'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  void dispose() {
    // 理论上这个dispose永远不会被调用，因为InviteHandler是根组件
    // 但保留代码是一个好习惯
    _newInviteSubscription.cancel();
    _matchStartedSubscription.cancel();
    _friendAcceptedSubscription.cancel();
    _listenersInitialized = false; // 在极少数情况下，如果它被销毁，允许下次重新初始化
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 这个widget本身是不可见的，它只是一个逻辑包装器
    return widget.child;
  }
}