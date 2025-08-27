//启动应用
import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'widgets/home.dart';
import 'widgets/test_page.dart';

// 应用程序入口点
void main() {
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
      // home: const HomePage(),  // 首页
      home: const TestPage(),  // 使用测试页作为启动页面
    );
  }
}

