// lib/config/app_config.dart

class AppConfig {
  /// 私有构造函数，防止外部实例化
  AppConfig._();

  /// 你的后端服务器的IP地址和端口号
  /// 【重要】这是你唯一需要修改的地方！
  static const String serverUrl = 'http://localhost:5000';
}
