import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  static const String _baseUrl = '${AppConfig.serverUrl}/api';

  String? _token;
  Map<String, dynamic>? _currentUser;
  String? get token => _token;

  // 单例模式，确保全局唯一实例
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool get isLoggedIn {
    final result = _token != null && _currentUser != null;
    print(
        'AuthService: isLoggedIn = $result, user = ${_currentUser?['username']}');
    return result;
  }

  Map<String, dynamic>? get currentUser => _currentUser;

  // 简化的加载认证数据（使用内存存储）
  Future<void> loadAuthData() async {
    // 这个版本使用内存存储，应用重启后需要重新登录
    // 但在应用运行期间会保持登录状态
    print('AuthService: 使用内存存储模式');

    // 如果有token，验证其有效性
    if (_token != null) {
      final isValid = await validateToken(_token!);
      if (!isValid) {
        print('AuthService: Token无效，清除数据');
        _token = null;
        _currentUser = null;
      }
    }
  }

  // 保存认证数据到内存
  void _saveAuthData(String token, Map<String, dynamic> user) {
    _token = token;
    _currentUser = user;
    print('AuthService: 保存用户数据到内存 - ${user['username']}');
  }

  // 清除认证数据
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    print('AuthService: 用户已退出登录');
  }

  // 用户登录
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('登录成功，保存数据: ${result['user']}');
        _saveAuthData(result['token'], result['user']);
        print('保存后状态: isLoggedIn=${isLoggedIn}, user=${currentUser}');
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '登录失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 用户注册
  Future<Map<String, dynamic>> register(
      String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        final result = jsonDecode(response.body);
        _saveAuthData(result['token'], result['user']);
        return result;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '注册失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 重置密码
  Future<void> resetPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '重置密码失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 验证Token
  Future<bool> validateToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/validate'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 提交分数
  Future<void> submitScore(int score, int time, String difficulty) async {
    if (!isLoggedIn) {
      throw Exception('请先登录');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/scores'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'score': score,
          'time': time,
          'difficulty': difficulty,
        }),
      );

      if (response.statusCode == 201) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '提交分数失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 获取排行榜
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    if (!isLoggedIn) {
      throw Exception('请先登录');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/scores'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> scores = jsonDecode(response.body);
        return scores.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '获取排行榜失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 获取用户资料
  Future<Map<String, dynamic>> getUserProfile() async {
    if (!isLoggedIn) {
      throw Exception('请先登录');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/user/profile'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '获取用户资料失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 提交游戏存档
  Future<void> submitSave(Map<String, dynamic> saveData) async {
    if (!isLoggedIn) {
      throw Exception('请先登录');
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/save-game'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode(saveData),
      );

      if (response.statusCode == 201) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '提交存档失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 加载游戏存档
  Future<Map<String, dynamic>?> loadSave(
      String gameMode, int difficulty) async {
    if (!isLoggedIn) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/load-save?gameMode=$gameMode&difficulty=$difficulty'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null; // 存档不存在
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '加载存档失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // 删除游戏存档
  Future<void> deleteSave(String gameMode, int difficulty) async {
    if (!isLoggedIn) {
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(
            '$_baseUrl/delete-save?gameMode=$gameMode&difficulty=$difficulty'),
        headers: {
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        return;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? '删除存档失败');
      }
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('网络连接失败，请检查服务器是否启动');
    }
  }

  // Placeholder: Add if getToken doesn't exist
  static Future<String?> getToken() async {
    // Implement token retrieval, e.g., from shared preferences or secure storage
    // For now, return a dummy token or null
    return 'dummy-token'; // Replace with actual implementation
  }
}
