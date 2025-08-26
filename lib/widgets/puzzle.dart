//游戏界面
//->主页
//->游戏界面
import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'home.dart';

class PuzzlePage extends StatelessWidget {
  const PuzzlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("拼图游戏"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这里将来放置拼图游戏的主要内容
            const Text("游戏内容将在此处实现", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 40),
            Button_toRestart(context),
            const SizedBox(height: 20),
            Button_toHome(context),
          ],
        ),
      ),
    );
  }
}

ElevatedButton Button_toRestart(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PuzzlePage()),
      );
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      backgroundColor: Colors.green,
      foregroundColor: Colors.white,
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.refresh),
        SizedBox(width: 10),
        Text('重新开始', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

ElevatedButton Button_toHome(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.home),
        SizedBox(width: 10),
        Text('返回主页', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}
