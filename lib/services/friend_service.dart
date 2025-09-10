// lib/services/friend_service.dart (完整代码)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/friend.dart';
import '../config/app_config.dart';
import '../models/match_history.dart'; // <-- 新增的 import

class FriendService {
  // 【已对齐】使用你 AuthService 中提供的 IP 地址
  static const String _baseUrl = '${AppConfig.serverUrl}/api';

  // 使用AuthService单例来获取服务实例
  final AuthService _authService = AuthService();

  // 内部辅助方法，用于安全地获取token
  String _getToken() {
    // 【已对齐】使用我们刚刚在 AuthService 中添加的公共 getter
    final token = _authService.token;
    if (token == null) {
      throw Exception('用户未登录或Token无效');
    }
    return token;
  }

  /// 获取当前用户的好友列表
  Future<List<Friend>> getFriends() async {
    final token = _getToken();

    final response = await http.get(
      Uri.parse('$_baseUrl/friends'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Friend.fromJson(json)).toList();
    } else {
      print('Failed to load friends: ${response.body}');
      throw Exception('加载好友列表失败');
    }
  }

  /// 获取收到的好友请求列表
  Future<List<FriendRequest>> getFriendRequests() async {
    final token = _getToken();

    final response = await http.get(
      Uri.parse('$_baseUrl/friends/requests'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => FriendRequest.fromJson(json)).toList();
    } else {
      throw Exception('加载好友请求失败');
    }
  }

  /// 根据关键词搜索用户
  Future<List<SearchedUser>> searchUsers(String query) async {
    final token = _getToken();

    final response = await http.get(
      Uri.parse('$_baseUrl/users/search?query=$query'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => SearchedUser.fromJson(json)).toList();
    } else {
      throw Exception('搜索用户失败');
    }
  }

  /// 发送好友请求
  Future<void> sendFriendRequest(int targetUserId) async {
    final token = _getToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/friends/request'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'target_user_id': targetUserId}),
    );

    if (response.statusCode != 201) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? '发送好友请求失败');
    }
  }

  /// 回应好友请求 (接受或拒绝)
  Future<void> respondToFriendRequest(int friendshipId, String action) async {
    final token = _getToken();

    final response = await http.post(
      Uri.parse('$_baseUrl/friends/respond'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'friendship_id': friendshipId,
        'action': action, // 'accept' or 'decline'
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? '回应好友请求失败');
    }
  }

  // ▼▼▼ 新增的方法 ▼▼▼
  /// 获取对战历史记录
  Future<List<MatchHistory>> getMatchHistory() async {
    final token = _getToken();

    final response = await http.get(
      Uri.parse('$_baseUrl/matches/history'), // <-- 新的 API 路由
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => MatchHistory.fromJson(json)).toList();
    } else {
      print('Failed to load match history: ${response.body}');
      throw Exception('加载对战记录失败');
    }
  }
// ▲▲▲ 新增结束 ▲▲▲
}