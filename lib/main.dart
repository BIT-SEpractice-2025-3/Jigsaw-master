//启动应用
import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'widgets/home.dart';
import 'package:flutter/services.dart';  // 导入系统服务包

// 应用程序入口点
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //隐藏导航栏但允许上滑显示
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  runApp(const PuzzleApp());  // 运行拼图应用
}

// 应用的根部件
class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拼图大师',  // 应用名称
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),  // 首页
      // home: const TestPage(),  // 使用测试页作为启动页面
    );
  }
}

