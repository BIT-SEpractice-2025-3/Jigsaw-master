//拼图数据模型
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 拼图碎片类
class PuzzlePiece {
  final ui.Image image;        // 碎片图像
  final int originalIndex;     // 原始位置索引
  final int currentIndex;      // 当前位置索引
  final Offset originalPosition; // 原始位置坐标

  PuzzlePiece({
    required this.image,
    required this.originalIndex,
    required this.currentIndex,
    required this.originalPosition,
  });

  // 创建一个新的拼图碎片，更新当前索引
  PuzzlePiece copyWith({int? newCurrentIndex}) {
    return PuzzlePiece(
      image: image,
      originalIndex: originalIndex,
      currentIndex: newCurrentIndex ?? currentIndex,
      originalPosition: originalPosition,
    );
  }
}