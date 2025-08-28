//拼图数据模型
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 拼图碎片类
class PuzzlePiece {
  final ui.Image image;
  final int nodeId;

  /// 这块拼图在完整拼图中的正确左上角坐标。
  /// UI将直接使用这个坐标来定位拼图块。
  final ui.Offset position;

  PuzzlePiece({
    required this.image,
    required this.nodeId,
    required this.position,
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