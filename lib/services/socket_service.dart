// lib/services/socket_service.dart

import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/match.dart';
import '../config/app_config.dart'; // 使用我们创建的配置文件
import 'auth_service.dart';       // <-- 1. 导入AuthService

class SocketService {
  // --- 单例模式设置 ---
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  // --- 私有变量 ---
  IO.Socket? _socket;
  // <-- 2. 获取AuthService的实例，以便后面能拿到token
  final AuthService _authService = AuthService();

  // --- StreamControllers (设为私有) ---
  final StreamController<Map<String, dynamic>> _onNewInviteController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Match> _onMatchStartedController = StreamController<Match>.broadcast();
  final StreamController<Map<String, dynamic>> _onMatchOverController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<double> _onOpponentProgressController = StreamController<double>.broadcast();
  final StreamController<Map<String, dynamic>> _onFriendStatusUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _onFriendRequestAcceptedController = StreamController<Map<String, dynamic>>.broadcast();

  // --- 公共的 Stream Getters (UI层从此监听) ---
  Stream<Map<String, dynamic>> get onNewInvite => _onNewInviteController.stream;
  Stream<Match> get onMatchStarted => _onMatchStartedController.stream;
  Stream<Map<String, dynamic>> get onMatchOver => _onMatchOverController.stream;
  Stream<double> get onOpponentProgress => _onOpponentProgressController.stream;
  Stream<Map<String, dynamic>> get onFriendStatusUpdate => _onFriendStatusUpdateController.stream;
  Stream<Map<String, dynamic>> get onFriendRequestAccepted => _onFriendRequestAcceptedController.stream;

  /// 连接并开始监听
  void connectAndListen(String token) {
    if (_socket?.connected == true) return;

    // 使用 AppConfig 来获取URL
    _socket = IO.io(AppConfig.serverUrl,
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build()
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      print('Socket connected: ${_socket!.id}');
      // 连接成功后，立即用token进行认证
      _socket!.emit('authenticate', {'token': token});
    });

    _socket!.onDisconnect((_) => print('Socket disconnected'));
    _socket!.onError((data) => print('Socket error: $data'));

    // --- 注册自定义事件监听 ---
    _socket!.on('authentication_success', (_) => print("Socket authentication successful!"));
    _socket!.on('authentication_failed', (data) => print("Socket authentication failed: $data"));

    _socket!.on('new_match_invite', (data) => _onNewInviteController.add(data));
    _socket!.on('match_started', (data) {
      final matchData = data['match'];
      if (matchData != null) {
        _onMatchStartedController.add(Match.fromJson(matchData));
      }
    });
    _socket!.on('match_over', (data) => _onMatchOverController.add(data));
    _socket!.on('opponent_progress_update', (data) => _onOpponentProgressController.add(data['progress']?.toDouble() ?? 0.0));
    _socket!.on('friend_status_update', (data) => _onFriendStatusUpdateController.add(data));
    _socket!.on('friend_request_accepted', (data) => _onFriendRequestAcceptedController.add(data));
  }

  // --- ▼▼▼ 核心修改部分 ▼▼▼ ---

  /// 3. 创建一个私有辅助函数，用于将token添加到任何传出的数据中
  Map<String, dynamic> _withToken(Map<String, dynamic> data) {
    final token = _authService.token;
    if (token == null) {
      print("SocketService 警告: 尝试发送需要认证的事件，但用户未登录或token为空。");
      // 即使token为空也返回原始数据，让后端决定如何处理
      return data;
    }
    // 使用Map的扩展运算符(...)来合并原始数据和token
    return {
      ...data,
      'token': token,
    };
  }

  // --- UI调用的方法: 向服务器发送事件 (现在都使用_withToken包装) ---

  void sendInvite(int opponentId, String difficulty, String imageSource) {
    if (_socket?.connected != true) return;
    // 2. 直接发送数据，不再用 _withToken 包装
    _socket!.emit('invite_to_match', {
      'opponent_id': opponentId,
      'difficulty': difficulty,
      'image_source': imageSource,
    });
  }

  void respondToInvite(int matchId, String response) {
    if (_socket?.connected != true) return;
    // 2. 直接发送数据
    _socket!.emit('respond_to_invite', {
      'match_id': matchId,
      'response': response,
    });
  }

  void updateProgress(int matchId, double progress) {
    if (_socket?.connected != true) return;
    // 2. 直接发送数据
    _socket!.emit('player_progress_update', {
      'match_id': matchId,
      'progress': progress,
    });
  }

  void playerFinished(int matchId, int timeMs) {
    if (_socket?.connected != true) return;
    // 2. 直接发送数据
    _socket!.emit('player_finished', {
      'match_id': matchId,
      'time_ms': timeMs,
    });
  }

  // --- ▲▲▲ 核心修改部分结束 ▲▲▲ ---

  void dispose() {
    print("Disposing SocketService...");
    _socket?.disconnect();
    _socket?.dispose();

    // 关闭所有StreamController
    _onNewInviteController.close();
    _onMatchStartedController.close();
    _onMatchOverController.close();
    _onOpponentProgressController.close();
    _onFriendStatusUpdateController.close();
    _onFriendRequestAcceptedController.close();
  }
}