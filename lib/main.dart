//启动应用
import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'widgets/home.dart';
import 'package:flutter/services.dart';  // 导入系统服务包
import 'widgets/puzzle_master.dart';
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
      // 直接打开大师模式主页，使用默认图片（请确认 assets/default.jpg 已在 pubspec.yaml 中声明）
      // home: PuzzleMasterPage(
      //   imageSource: 'assets/images/default_puzzle.jpg',
      //   difficulty: 1,
      // ),
      home: const HomePage(),  // 使用测试页作为启动页面
    );
  }
}
