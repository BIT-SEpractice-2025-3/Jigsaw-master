//全局设置界面
//->主页

import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'home.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("设置"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 这里将来放置设置页面的主要内容
            const Text("设置内容将在此处实现", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 40),
            Button_toHome(context),
          ],
        ),
      ),
    );
  }
}

//返回主页
ElevatedButton Button_toHome(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.pop(context);
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