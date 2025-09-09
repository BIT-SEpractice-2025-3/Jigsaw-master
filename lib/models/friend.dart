// lib/models/friend.dart

import 'package:flutter/material.dart';

/// 好友模型，用于好友列表
class Friend {
  final int id;
  final String username;
  String status; // 'online' or 'offline'

  Friend({
    required this.id,
    required this.username,
    required this.status,
  });

  /// 从JSON数据创建Friend对象的工厂构造函数
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'],
      username: json['username'],
      status: json['status'] ?? 'offline', // 如果后端没提供status，默认为offline
    );
  }

  /// 获取状态对应的颜色，方便UI使用
  Color get statusColor => status == 'online' ? Colors.green : Colors.grey;
}

/// 好友请求模型，用于好友请求列表
class FriendRequest {
  final int friendshipId; // friendships表的主键ID，用于同意或拒绝操作
  final int userId;       // 发送请求的用户ID
  final String username;   // 发送请求的用户名

  FriendRequest({
    required this.friendshipId,
    required this.userId,
    required this.username,
  });

  /// 从JSON数据创建FriendRequest对象的工厂构造函数
  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      friendshipId: json['friendship_id'],
      userId: json['user_id'],
      username: json['username'],
    );
  }
}

/// 搜索用户返回的模型
class SearchedUser {
  final int id;
  final String username;

  /// 与当前用户的关系状态
  /// - null: 无任何关系
  /// - 'pending': 已发送请求或已收到请求
  /// - 'accepted': 已是好友
  /// - 'blocked': 已拉黑
  final String? status;

  /// 如果状态是 'pending', 这个字段表示是谁发起的请求
  final int? actionUserId;

  SearchedUser({
    required this.id,
    required this.username,
    this.status,
    this.actionUserId,
  });

  /// 从JSON数据创建SearchedUser对象的工厂构造函数
  factory SearchedUser.fromJson(Map<String, dynamic> json) {
    return SearchedUser(
      id: json['id'],
      username: json['username'],
      status: json['status'], // 可以为null
      actionUserId: json['action_user_id'], // 可以为null
    );
  }
}