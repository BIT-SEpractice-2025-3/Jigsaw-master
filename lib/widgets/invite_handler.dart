// lib/widgets/invite_handler.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../pages/puzzle_battle_page.dart'; // 我们之后会创建这个页面
import '../models/match.dart';
import '../services/auth_service.dart'; // 引入AuthService

class InviteHandler extends StatefulWidget {
  final Widget child;
  const InviteHandler({super.key, required this.child});

  @override
  State<InviteHandler> createState() => _InviteHandlerState();
}

class _InviteHandlerState extends State<InviteHandler> {
  // 获取SocketService的单例
  final SocketService _socketService = SocketService();

  // StreamSubscription用于在widget销毁时取消监听，防止内存泄漏
  late StreamSubscription _newInviteSubscription;
  late StreamSubscription _matchStartedSubscription;
  late StreamSubscription _friendAcceptedSubscription;

  @override
  void initState() {
    super.initState();
    // 开始监听来自SocketService的各个事件流
    _newInviteSubscription = _socketService.onNewInvite.listen(_showInviteDialog);
    _matchStartedSubscription = _socketService.onMatchStarted.listen(_navigateToBattlePage);
    _friendAcceptedSubscription = _socketService.onFriendRequestAccepted.listen(_showFriendAcceptedSnackbar);
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
              SizedBox(width: 8),
              Text('对战邀请'),
            ],
          ),
          content: Text(
            '${inviteData['challenger_username']} 邀请你进行一场对战!',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('残忍拒绝'),
              onPressed: () {
                _socketService.respondToInvite(inviteData['match_id'], 'declined');
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: Text('接受挑战!'),
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
  void _navigateToBattlePage(Match match) {
    // 确保我们不在对战页面，避免重复进入
    if (ModalRoute.of(context)?.settings.name != '/puzzle-battle') {
      Navigator.push(
        context,
        MaterialPageRoute(
          // 给路由一个名字，用于上面的检查
          settings: const RouteSettings(name: '/puzzle-battle'),
          builder: (context) => PuzzleBattlePage(match: match),
        ),
      );
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
    // 在widget销毁时，必须取消所有监听，这是非常重要的一步！
    _newInviteSubscription.cancel();
    _matchStartedSubscription.cancel();
    _friendAcceptedSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 这个widget本身是不可见的，它只是一个逻辑包装器
    return widget.child;
  }
}