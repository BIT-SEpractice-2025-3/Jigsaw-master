//难度选择
//->游戏界面
//->主页

import 'package:flutter/material.dart';
import 'puzzle.dart';
import 'home.dart';

class GameSelectionPage extends StatelessWidget {
  const GameSelectionPage({super.key});

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title: const Text("难度选择"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Button_toPuzzleEasy(context),
            const SizedBox(height: 20),
            Button_toPuzzleMedium(context),
            const SizedBox(height: 20),
            Button_toPuzzleHard(context),
            const SizedBox(height: 40),
            Button_toHome(context),
          ],
        ),
      ),
    );
  }
}

ElevatedButton Button_toPuzzleEasy(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
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
        Icon(Icons.grid_3x3),
        SizedBox(width: 10),
        Text('简单 (3x3)', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

ElevatedButton Button_toPuzzleMedium(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PuzzlePage()),
      );
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      backgroundColor: Colors.orange,
      foregroundColor: Colors.white,
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.grid_4x4),
        SizedBox(width: 10),
        Text('中等 (4x4)', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

ElevatedButton Button_toPuzzleHard(BuildContext context){
  return ElevatedButton(
    onPressed:(){
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PuzzlePage()),
      );
    },
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.grid_on),
        SizedBox(width: 10),
        Text('困难 (5x5)', style: TextStyle(fontSize: 18)),
      ],
    ),
  );
}

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
