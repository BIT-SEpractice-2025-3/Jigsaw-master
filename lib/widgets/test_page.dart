import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import '../services/puzzle_generate_service.dart';
import '../models/puzzle_piece.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  Map<int, PuzzlePiece> _piecesMap = {};
  bool _isLoading = true;
  // !! 定义你的图片资源路径 !!
  final String _imagePath = 'assets/images/1.jpg';

  @override
  void initState() {
    super.initState();
    _generateAndSetPieces();
  }

  Future<void> _generateAndSetPieces() async {
    final service = PuzzleGenerateService();
    // !! 将图片路径传递给服务 !!
    final generatedPieces = await service.generatePuzzle(_imagePath, 1);

    setState(() {
      _piecesMap = { for (var piece in generatedPieces) piece.nodeId : piece };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("算法测试页面"),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _piecesMap.isEmpty
            ? const Text("生成失败！")
            : Container(
          width: 800,
          height: 800,
          color: Colors.grey.shade800,
          child: Stack(
            // 遍历 Map 中的所有 PuzzlePiece
            children: _piecesMap.values.map((piece) {
              final imageWidget = RawImage(image: piece.image);

              // 将每个拼图块包装在 Draggable 小部件中
              return Positioned(
                left: piece.position.dx,
                top: piece.position.dy,
                child: Draggable<PuzzlePiece>(
                  // data: 拖动时携带的数据，这里是拼图块本身
                  data: piece,

                  // feedback: 拖动过程中跟随手指移动的小部件
                  feedback: imageWidget,

                  // childWhenDragging: 原位置在拖动开始后显示的小部件
                  // 这里我们显示一个半透明的原图块，以提供更好的视觉反馈
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: imageWidget,
                  ),

                  // onDragEnd: 拖动结束后的回调
                  onDragEnd: (details) {
                    // details.offset 是拖动结束时，手指在屏幕上的全局坐标
                    // 我们需要将其转换为相对于Stack容器的局部坐标
                    final appBarHeight = AppBar().preferredSize.height;
                    final statusBarHeight = MediaQuery.of(context).viewPadding.top;

                    // 计算出新的左上角坐标
                    final newLeft = details.offset.dx;
                    final newTop = details.offset.dy - appBarHeight - statusBarHeight;

                    // 更新状态
                    setState(() {
                      // 创建一个新的 PuzzlePiece 实例来替换旧的
                      _piecesMap[piece.nodeId] = PuzzlePiece(
                        image: piece.image,
                        nodeId: piece.nodeId,
                        position: Offset(newLeft, newTop),
                      );
                    });
                  },

                  // child: 拖动开始前，在原位置显示的小部件
                  child: imageWidget,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}