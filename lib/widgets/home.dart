//主页
//->难度选择
//->排行榜
//->设置
//->自定义

import 'package:flutter/material.dart';  // 导入Flutter的材料设计库
import 'game_select.dart';
import 'ranking.dart';
import 'setting.dart';
import 'diy.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
        appBar: AppBar(
          title: const Text('拼图大师'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Button_toGameSelect(context),
              const SizedBox(height: 20),
              Button_toRanking(context),
              const SizedBox(height: 20),
              Button_toDiy(context),
              const SizedBox(height: 20),
              Button_toSetting(context),
            ],
          ),
        )
    );
  }
}

ElevatedButton Button_toGameSelect(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const GameSelectionPage()),
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
        Icon(Icons.gamepad),
        SizedBox(width: 10),
        Text('开始拼图', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

ElevatedButton Button_toRanking(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RankingPage()),
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
        Icon(Icons.leaderboard),
        SizedBox(width: 10),
        Text('排行榜', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

ElevatedButton Button_toSetting(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingPage()),
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
        Icon(Icons.settings),
        SizedBox(width: 10),
        Text('设置', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}
ElevatedButton Button_toDiy(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DiyPage()),
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
        Icon(Icons.settings),
        SizedBox(width: 10),
        Text('自定义拼图', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}
