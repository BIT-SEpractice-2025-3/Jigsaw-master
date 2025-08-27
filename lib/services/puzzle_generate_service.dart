//生成拼图
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import '/models/puzzle_piece.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PuzzleGenerateService {
  /// 公开的API：根据图片源和难度生成拼图块列表
  Future<List<PuzzlePiece>> generatePuzzle(
      String imageSource, int difficulty) async {
    // 智能加载图片
    ui.Image image;
    if (imageSource.startsWith('assets/')) {
      image = await _loadImageFromAsset(imageSource);
    } else {
      image = await _loadImageFromFile(imageSource);
    }

    // 根据难度确定网格大小
    int gridSize = _getDifficultySize(difficulty);

    // 调用核心的图片切割函数
    return _sliceImage(image, gridSize);
  }
  Future<ui.Image> _createPlaceholderImage(int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.grey.shade300;
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
    return await recorder.endRecording().toImage(width, height);
  }
  static PuzzleEdge? _findEdge(PuzzleGraph graph, int node1Id, int node2Id) {
    if (!graph.nodes.containsKey(node1Id) || !graph.nodes.containsKey(node2Id)) {
      return null;
    }
    for (var edgeId in graph.nodes[node1Id]!.neighborEdges) {
      final edge = graph.edges[edgeId]!;
      if ((edge.nodeA_id == node1Id && edge.nodeB_id == node2Id) ||
          (edge.nodeA_id == node2Id && edge.nodeB_id == node1Id)) {
        return edge;
      }
    }
    return null;
  }

  // 从资源(assets)加载图片
  Future<ui.Image> _loadImageFromAsset(String assetPath) async {
    // 1. 从资源路径加载二进制数据
    final ByteData data = await rootBundle.load(assetPath);
    // 2. 将二进制数据转换为Uint8List
    final Uint8List bytes = data.buffer.asUint8List();
    // 3. 解码Uint8List为ui.Image
    return _decodeImage(bytes);
  }

  // 从文件加载图片
  Future<ui.Image> _loadImageFromFile(String filePath) async {
    // 1. 从文件路径读取二进制数据
    final Uint8List bytes = await File(filePath).readAsBytes();
    // 2. 解码Uint8List为ui.Image
    return _decodeImage(bytes);
  }

  // 辅助函数：将字节列表解码为ui.Image
  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    // 使用Flutter引擎的内置解码器
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  // 根据难度确定拼图网格大小
  int _getDifficultySize(int difficulty) {
    switch (difficulty) {
      case 1: return 3; // 简单 3x3
      case 2: return 4; // 中等 4x4
      case 3: return 5; // 困难 5x5
      default: return 3;
    }
  }
  static PuzzleGraph generateGridGraph(int rows, int cols) {
    final graph = PuzzleGraph();
    int edgeIdCounter = 0;

    // --- 步骤 1: 循环生成所有节点 ---
    // 遍历每一个虚拟的网格单元，为其创建一个逻辑上的节点。
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // 使用 (row * cols + col) 公式将二维坐标转换为一维的、唯一的ID。
        final nodeId = row * cols + col;
        final node = PuzzleNode(id: nodeId);
        graph.nodes[nodeId] = node;
      }
    }

    // --- 步骤 2: 再次循环，为节点之间创建连接边 ---
    // 再次遍历所有节点，这次我们检查每个节点的右边和下边，
    // 以建立它们与邻居的连接关系。
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final currentNodeId = row * cols + col;

        // 检查右边的邻居是否存在 (即当前列不是最后一列)
        if (col < cols - 1) {
          final rightNeighborId = row * cols + (col + 1);

          // 创建一条边来连接当前节点和它的右邻居
          final edge = PuzzleEdge(
            id: edgeIdCounter++,
            nodeA_id: currentNodeId,
            nodeB_id: rightNeighborId,
          );
          graph.edges[edge.id] = edge;

          // 同时更新两个节点，让它们知道自己通过这条边连接了起来
          graph.nodes[currentNodeId]!.neighborEdges.add(edge.id);
          graph.nodes[rightNeighborId]!.neighborEdges.add(edge.id);
        }

        // 检查下边的邻居是否存在 (即当前行不是最后一行)
        if (row < rows - 1) {
          final downNeighborId = (row + 1) * cols + col;

          // 创建一条边来连接当前节点和它的下邻居
          final edge = PuzzleEdge(
            id: edgeIdCounter++,
            nodeA_id: currentNodeId,
            nodeB_id: downNeighborId,
          );
          graph.edges[edge.id] = edge;

          // 同样，更新两个相连的节点
          graph.nodes[currentNodeId]!.neighborEdges.add(edge.id);
          graph.nodes[downNeighborId]!.neighborEdges.add(edge.id);
        }
      }
    }

    return graph;
  }
  /// @param length 这条边的直线长度。
  /// @param bumpHeight 凸起/凹陷的高度。正值表示高度。
  /// @param isConvex 决定边缘是凸起还是凹陷。true为凸，false为凹。
  /// @return 返回一个描述边缘形状的 Path 对象。
  static Path generatePuzzleEdgePath(
      double length,
      double bumpHeight,
      bool isConvex,
      ) {
    final path = Path();

    // 移动到路径的起点
    path.moveTo(0, 0);

    // 凸起/凹陷的方向由 sign 决定 (1.0 为凸, -1.0 为凹)
    final double sign = isConvex ? 1.0 : -1.0;

    // 为了美观，凸起部分不占满整个边长，我们留出一些边距
    final double bumpRatio = 0.35; // 凸起部分大约占边长的 30% (0.35 -> 0.65)
    final double straightStart = length * bumpRatio;
    final double straightEnd = length * (1.0 - bumpRatio);

    // --- 绘制第一段直线 ---
    path.lineTo(straightStart, 0);

    // 我们使用两条三次贝塞尔曲线来构造一个平滑的、对称的凸起

    // 从第一段直线末端到凸起的最高点
    path.cubicTo(
      length * 0.40, 0,                     // 第1个控制点 (影响离开直线的弧度)
      length * 0.35, sign * bumpHeight,     // 第2个控制点 (影响凸起的形状和高度)
      length * 0.50, sign * bumpHeight,     // 曲线的终点 (即凸起的顶点)
    );

    // 从凸起的最高点回到第二段直线
    path.cubicTo(
      length * 0.65, sign * bumpHeight,     // 第3个控制点 (镜像于第2个控制点)
      length * 0.60, 0,                     // 第4个控制点 (镜像于第1个控制点)
      straightEnd, 0,                       // 曲线的终点 (回到主线上)
    );

    // --- 绘制最后一段直线，直到边的终点 ---
    path.lineTo(length, 0);

    return path;
  }
  // 将图片切割成网格状的拼图碎片
  Future<List<PuzzlePiece>> _sliceImage(ui.Image image, int gridSize) async {
    final pieces = <PuzzlePiece>[];
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    // --- 1. 获取图蓝图 ---
    final graph = generateGridGraph(gridSize, gridSize);

    // --- 2. 随机化边缘 ---
    final random = Random();
    for (var edge in graph.edges.values) {
      edge.isConvexOnA = random.nextBool();
    }

    // --- 3. 计算几何尺寸 ---
    final pieceWidth = imageWidth / gridSize;
    final pieceHeight = imageHeight / gridSize;
    final bumpSize = pieceWidth * 0.2;

    // --- 4. 遍历节点生成每个拼图块 ---
    for (var node in graph.nodes.values) {
      final finalPath = Path();
      final row = node.id ~/ gridSize;
      final col = node.id % gridSize;

      final offsetX = col * pieceWidth;
      final offsetY = row * pieceHeight;

// --- 5. 组装拼图块的轮廓路径 ---
      // 定义四个角的坐标，方便理解
      final topLeft = Offset(offsetX, offsetY);
      final topRight = Offset(offsetX + pieceWidth, offsetY);
      final bottomRight = Offset(offsetX + pieceWidth, offsetY + pieceHeight);
      final bottomLeft = Offset(offsetX, offsetY + pieceHeight);

      // 从左上角开始
      finalPath.moveTo(topLeft.dx, topLeft.dy);

      // -- 上边 --
      final topNeighborId = (row - 1) * gridSize + col;
      final topEdge = _findEdge(graph, node.id, topNeighborId);
      if (topEdge == null) {
        finalPath.lineTo(topRight.dx, topRight.dy);
      } else {
        final isConvex = (topEdge.nodeA_id == node.id) ? topEdge.isConvexOnA : !topEdge.isConvexOnA;
        final edgePath = generatePuzzleEdgePath(pieceWidth, bumpSize, isConvex);
        // 使用 addPath 开始第一个路径段
        finalPath.addPath(edgePath, topLeft);
      }

      // -- 右边 --
      final rightNeighborId = row * gridSize + (col + 1);
      final rightEdge = _findEdge(graph, node.id, rightNeighborId);
      if (rightEdge == null) {
        finalPath.lineTo(bottomRight.dx, bottomRight.dy);
      } else {
        final isConvex = (rightEdge.nodeA_id == node.id) ? rightEdge.isConvexOnA : !rightEdge.isConvexOnA;
        var edgePath = generatePuzzleEdgePath(pieceHeight, bumpSize, isConvex);
        final matrix = Matrix4.identity()
          ..translate(topRight.dx, topRight.dy)
          ..rotateZ(pi / 2);
        // 使用 extendWithPath 连接后续的路径段
        finalPath.extendWithPath(edgePath.transform(matrix.storage), Offset.zero);
      }

      // -- 下边 --
      final bottomNeighborId = (row + 1) * gridSize + col;
      final bottomEdge = _findEdge(graph, node.id, bottomNeighborId);
      if (bottomEdge == null) {
        finalPath.lineTo(bottomLeft.dx, bottomLeft.dy);
      } else {
        final isConvex = (bottomEdge.nodeA_id == node.id) ? bottomEdge.isConvexOnA : !bottomEdge.isConvexOnA;
        var edgePath = generatePuzzleEdgePath(pieceWidth, bumpSize, isConvex);
        final matrix = Matrix4.identity()
          ..translate(bottomRight.dx, bottomRight.dy)
          ..rotateZ(pi);
        finalPath.extendWithPath(edgePath.transform(matrix.storage), Offset.zero);
      }

      // -- 左边 --
      final leftNeighborId = row * gridSize + (col - 1);
      final leftEdge = _findEdge(graph, node.id, leftNeighborId);
      if (leftEdge == null) {
        finalPath.lineTo(topLeft.dx, topLeft.dy);
      } else {
        final isConvex = (leftEdge.nodeA_id == node.id) ? leftEdge.isConvexOnA : !leftEdge.isConvexOnA;
        var edgePath = generatePuzzleEdgePath(pieceHeight, bumpSize, isConvex);
        final matrix = Matrix4.identity()
          ..translate(bottomLeft.dx, bottomLeft.dy)
          ..rotateZ(3 * pi / 2);
        finalPath.extendWithPath(edgePath.transform(matrix.storage), Offset.zero);
      }

      // 封闭路径，确保首尾相连
      finalPath.close();
// --- 6. 执行切割 ---
      final bounds = finalPath.getBounds();
      final recorder = ui.PictureRecorder();

      // 创建一个尺寸与拼图块边界框完全相同的画布
      final canvas = Canvas(recorder, bounds);

      // 将在全局坐标系下的 finalPath，平移到当前画布的局部坐标系 (左上角为0,0)
      final localPath = finalPath.shift(-bounds.topLeft);

      // 1. 设置裁剪区域：后续的绘制操作将只在此路径内部生效
      canvas.clipPath(localPath);

      // 2. 将原始大图绘制上去
      canvas.drawImage(image, -bounds.topLeft, Paint());


      final picture = recorder.endRecording();
      final pieceImage = await picture.toImage(
        bounds.width.ceil(),
        bounds.height.ceil(),
      );
      // --- 7. 封装并添加到列表---
      final piece = PuzzlePiece(
        image: pieceImage,
        nodeId: node.id,
        position: bounds.topLeft,
      );
      pieces.add(piece);
    }
    return pieces;
  }

}
