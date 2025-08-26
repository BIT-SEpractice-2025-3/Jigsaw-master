//自定义拼图界面
//->主页
import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'home.dart';

class DiyPage extends StatelessWidget {
  const DiyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("自定义拼图"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这里将来放置自定义拼图的主要内容
            const Text("自定义拼图功能将在此处实现", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 40),
            Button_toHome(context),
          ],
        ),
      ),
    );
  }
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
