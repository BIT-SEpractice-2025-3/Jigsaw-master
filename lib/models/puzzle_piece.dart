import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 拼图碎片类
class PuzzlePiece {
  final ui.Image image;
  final int nodeId;

  /// 这块拼图在完整拼图中的正确物理左上角坐标。
  /// UI将直接使用这个坐标来定位和旋转拼图块。
  final ui.Offset position;

  /// 拼图块的实际路径形状，用于精确绘制高亮效果
  final Path shapePath;

  /// 拼图块在原图中的实际边界
  final Rect bounds;

  // 新增：拼图块的基础尺寸（不含凹凸）
  final double pieceSize;

  // 新增：在 shapePath 和 bounds 坐标系中，物理左上角（旋转中心）的位置
  final ui.Offset pivot;

  // 新增：邻居信息, key: 'top'|'right'|'bottom'|'left', value: 邻居nodeId
  final Map<String, int?> neighbors;
  // 新增：边缘类型, key: 'top'|'right'|'bottom'|'left', value: true为凸, false为凹
  final Map<String, bool?> edgeTypes;

  PuzzlePiece({
    required this.image,
    required this.nodeId,
    required this.position,
    required this.shapePath,
    required this.bounds,
    required this.pieceSize,
    required this.pivot,
    this.neighbors = const {},
    this.edgeTypes = const {},
  });
}

class PuzzleNode {
  /// 节点的唯一标识符, 例如，在3x3网格中，ID可以是 0 到 8。
  final int id;

  /// 存储连接到此节点的“边”的ID列表。
  /// 通过这个列表，我们可以找到所有与此节点相邻的边。
  final List<int> neighborEdges = [];

  PuzzleNode({
    required this.id,
  });
}

/// 拼图边类 (代表两个拼图块之间的抽象连接)
///
/// 这是定义拼图块之间如何拼接的核心，描述了一种连接关系。
class PuzzleEdge {
  /// 边的唯一标识符。
  final int id;

  /// 这条边连接的第一个节点的ID。
  final int nodeA_id;

  /// 这条边连接的第二个节点的ID。
  final int nodeB_id;

  /// 决定边的凹凸形状。
  /// - `true`: 这条边在 nodeA 视角是“凸起”的，在 nodeB 视角则是“凹陷”的。
  /// - `false`: 这条边在 nodeA 视角是“凹陷”的，在 nodeB 视角则是“凸起”的。
  late bool isConvexOnA;

  PuzzleEdge({
    required this.id,
    required this.nodeA_id,
    required this.nodeB_id,
  });
}

/// 拼图图结构类 (整个拼图的抽象拓扑结构)
///
/// 这是一个容器，用来管理所有的节点和边，
/// 完整地描述了一副拼图的结构。
class PuzzleGraph {
  /// 存储所有的拼图节点，通过节点的ID进行索引，方便快速查找。
  final Map<int, PuzzleNode> nodes = {};

  /// 存储所有的拼图边，通过边的ID进行索引。
  final Map<int, PuzzleEdge> edges = {};
}