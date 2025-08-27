// test_page.dart

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
  final String _imagePath = 'assets/images/1.jpg'; // 确保图片路径正确
  Size _imageSize = Size.zero;
  final Size _containerSize = const Size(400, 400); // 拼图容器的UI尺寸
  double _scale = 1.0;

  final GlobalKey _stackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _generateAndSetPieces();
  }

  Future<void> _generateAndSetPieces() async {
    if (!mounted) return;
    final service = PuzzleGenerateService();
    final generatedPieces = await service.generatePuzzle(_imagePath, 2);
    final ui.Image? sourceImage = service.lastLoadedImage;

    if (sourceImage == null) {
      setState(() { _isLoading = false; });
      return;
    }

    setState(() {
      _imageSize = Size(sourceImage.width.toDouble(), sourceImage.height.toDouble());
      _scale = _containerSize.width / _imageSize.width;
      _piecesMap = { for (var piece in generatedPieces) piece.nodeId : piece };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("拼图测试 (可拖动)"),
        backgroundColor: Colors.teal,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : _piecesMap.isEmpty
            ? const Text("生成失败！")
            : Container(
          key: _stackKey,
          width: _containerSize.width,
          height: _containerSize.height,
          color: Colors.grey.shade800,
          child: Stack(
            children: _piecesMap.values.map((piece) {
              final imageWidget = Transform.scale(
                scale: _scale,
                alignment: Alignment.topLeft,
                child: RawImage(image: piece.image, fit: BoxFit.fill),
              );

              return Positioned(
                left: piece.position.dx * _scale,
                top: piece.position.dy * _scale,
                child: Draggable<PuzzlePiece>(
                  data: piece,
                  feedback: Transform.scale(
                    scale: _scale,
                    alignment: Alignment.topLeft,
                    child: RawImage(image: piece.image, fit: BoxFit.fill),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: imageWidget,
                  ),
                  onDragEnd: (details) {
                    final RenderBox? stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
                    if (stackBox == null) return;
                    final Offset localOffset = stackBox.globalToLocal(details.offset);
                    setState(() {
                      _piecesMap[piece.nodeId] = PuzzlePiece(
                        image: piece.image,
                        nodeId: piece.nodeId,
                        position: Offset(localOffset.dx / _scale, localOffset.dy / _scale),
                      );
                    });
                  },
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