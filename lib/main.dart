import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'widgets/home.dart';
import 'services/auth_service.dart';
import 'package:flutter/services.dart'; // 导入系统服务包
import 'widgets/invite_handler.dart';

// 应用程序入口点
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  //隐藏导航栏但允许上滑显示
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );
  runApp(const PuzzleApp()); // 运行拼图应用
}

// 应用的根部件
class PuzzleApp extends StatelessWidget {
  const PuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '拼图大师', // 应用名称
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: FutureBuilder(
        future: _initializeApp(),
        builder: (context, snapshot) {
          // 等待初始化完成后显示主页
          if (snapshot.connectionState == ConnectionState.done) {
            return const InviteHandler(child: HomePage());
          } else {
            // 显示加载画面
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在加载...'),
                  ],
                ),
              ),
            );
          }
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }

  Future<void> _initializeApp() async {
    await AuthService().loadAuthData();
  }
}
