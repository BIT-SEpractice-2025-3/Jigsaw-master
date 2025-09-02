//自定义拼图界面
//->主页
import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'package:image_picker/image_picker.dart'; // 导入图片选择器
import 'package:path_provider/path_provider.dart';
import 'dart:io'; // 导入IO库，用于处理文件
import 'dart:convert'; // 导入JSON处理库
import 'package:path/path.dart' as path; // 导入路径处理库
import 'package:file_picker/file_picker.dart';
import 'home.dart';
import 'puzzle.dart';
import '../services/puzzle_generate_service.dart';
import '../models/puzzle_piece.dart';

class DiyPage extends StatefulWidget {
  const DiyPage({super.key});

  @override
  State<DiyPage> createState() => _DiyPageState();
}

class _DiyPageState extends State<DiyPage> {
  File? _selectedImage; // 导入图片后临时储存的图片
  String? _savedImagePath; // 保存的图片路径
  final ImagePicker _picker = ImagePicker(); // 读取图片工具
  bool _showPreview = false; // 是否已经显示了预览
  int _gridSize = 3; // 默认3x3网格
  List<PuzzlePiece>? _previewPieces; // 用于存储预览拼图块

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "自定义拼图",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2B55),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF6A5ACD)),
      ),
      body: Stack(
        children: [
          // 背景装饰
          _buildBackgroundDecoration(context),

          // 主要内容
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20.0 : 40.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 页面标题
                _buildPageTitle(),
                SizedBox(height: isSmallScreen ? 40 : 50),

                // 预览图片
                if (_selectedImage != null || _savedImagePath != null) ...[
                  _buildImagePreviewSection(),
                  SizedBox(height: isSmallScreen ? 30 : 40),
                ],

                // 图片选择按钮
                _buildImageSelectionButton(),
                SizedBox(height: isSmallScreen ? 30 : 40),

                // 开始游戏按钮
                if (_selectedImage != null || _savedImagePath != null) ...[
                  _buildStartPuzzleButton(context),
                  SizedBox(height: isSmallScreen ? 30 : 40),
                ],

                // 返回主页按钮
                _buildHomeButton(context),

                // 底部额外间距，确保内容不被遮挡
                SizedBox(height: isSmallScreen ? 30 : 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建背景装饰
  Widget _buildBackgroundDecoration(BuildContext context) {
    return Stack(
      children: [
        // 背景渐变
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF3F4F8),
                Color(0xFFE8EAF6),
                Color(0xFFF3F4F8),
              ],
            ),
          ),
        ),

        // 左上角拼图元素
        Positioned(
          top: -30,
          left: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x306A5ACD),
            size: 120,
            rotation: 0.2,
          ),
        ),

        // 右上角拼图元素
        Positioned(
          top: 50,
          right: -40,
          child: _buildPuzzleDecoration(
            color: const Color(0x30FF9800),
            size: 100,
            rotation: -0.3,
          ),
        ),

        // 左下角拼图元素
        Positioned(
          bottom: 80,
          left: -50,
          child: _buildPuzzleDecoration(
            color: const Color(0x30E91E63),
            size: 110,
            rotation: 0.7,
          ),
        ),

        // 右下角拼图元素
        Positioned(
          bottom: -40,
          right: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x304CAF50),
            size: 130,
            rotation: -0.5,
          ),
        ),
      ],
    );
  }

  // 构建拼图装饰元素
  Widget _buildPuzzleDecoration({
    required Color color,
    required double size,
    double rotation = 0.0,
  }) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: CustomPaint(
          painter: _PuzzlePiecePainter(color: color),
        ),
      ),
    );
  }

  // 构建页面标题
  Widget _buildPageTitle() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6A5ACD).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.photo_library_rounded,
            size: 48,
            color: Color(0xFF6A5ACD),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '自定义拼图',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2B55),
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                blurRadius: 4.0,
                color: Colors.black12,
                offset: Offset(2.0, 2.0),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '上传您的图片，创建专属拼图挑战',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // 构建图片预览部分
  Widget _buildImagePreviewSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final imageSize = isSmallScreen
        ? screenSize.width * 0.75
        : 320.0; // 移动端使用屏幕宽度的75%，桌面端固定320px

    return Material(
      borderRadius: BorderRadius.circular(28),
      elevation: 12,
      shadowColor: const Color(0xFF6A5ACD).withOpacity(0.2),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF6A5ACD).withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // 图片预览容器
            Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFF6A5ACD).withOpacity(0.25), width: 2),
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF6A5ACD).withOpacity(0.05),
                    const Color(0xFFE8EAF6),
                  ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _showPreview
                    ? _buildPuzzlePreview()
                    : (_selectedImage != null
                        ? Image.file(
                            _selectedImage!,
                            width: imageSize - 4,
                            height: imageSize - 4,
                            fit: BoxFit.contain,
                          )
                        : (_savedImagePath != null
                            ? Image.asset(
                                _savedImagePath!,
                                width: imageSize - 4,
                                height: imageSize - 4,
                                fit: BoxFit.contain,
                              )
                            : _buildPlaceholder(imageSize))),
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 28),

            // 难度选择
            _buildDifficultySelector(),
            SizedBox(height: isSmallScreen ? 20 : 24),

            // 预览切换按钮
            _buildPreviewToggleButton(),
            SizedBox(height: isSmallScreen ? 20 : 24),

            // 保存按钮
            _buildSaveButton(),

            // 底部空白间距
            SizedBox(height: isSmallScreen ? 40 : 60),
          ],
        ),
      ),
    );
  }

  // 构建占位符
  Widget _buildPlaceholder(double size) {
    return Container(
      width: size - 4,
      height: size - 4,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: size * 0.2,
            color: const Color(0xFF6A5ACD).withOpacity(0.6),
          ),
          const SizedBox(height: 12),
          Text(
            '选择图片开始',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF6A5ACD).withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // 构建开始拼图按钮
  Widget _buildStartPuzzleButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Container(
      width: isSmallScreen ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: _selectedImage != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFF9800),
                  const Color(0xFFFF9800).withOpacity(0.8),
                ],
              )
            : null,
        boxShadow: _selectedImage != null
            ? [
                BoxShadow(
                  color: const Color(0xFFFF9800).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: _selectedImage != null
            ? () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '开始${_gridSize}x$_gridSize拼图，难度：${_getDifficultyText()}'),
                    backgroundColor: Colors.green,
                  ),
                );

                final imagePath = _savedImagePath ?? _selectedImage!.path;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PuzzlePage(
                      imagePath: imagePath,
                      difficulty: _mapGridSizeToDifficulty(_gridSize),
                    ),
                  ),
                );
              }
            : null,
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: const Text(
          '开始拼图',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedImage != null
              ? Colors.transparent
              : Colors.grey.shade300,
          foregroundColor:
              _selectedImage != null ? Colors.white : Colors.grey.shade600,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 24 : 30,
            vertical: isSmallScreen ? 18 : 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  // 构建图片选择按钮
  Widget _buildImageSelectionButton() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? double.infinity : 650,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(28),
          elevation: 8,
          shadowColor: const Color(0xFF6A5ACD).withOpacity(0.15),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 28 : 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF6A5ACD).withOpacity(0.12),
                width: 1,
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFF6A5ACD).withOpacity(0.02),
                ],
              ),
            ),
            child: Column(
              children: [
                if (isSmallScreen)
                  // 移动端：垂直布局
                  Column(
                    children: [
                      _buildActionButton(
                        icon: Icons.photo_library_rounded,
                        label: '从相册选择',
                        color: const Color(0xFF6A5ACD),
                        onPressed: _pickImage,
                        isFullWidth: true,
                      ),
                      const SizedBox(height: 20),
                      _buildActionButton(
                        icon: Icons.download_rounded,
                        label: '导入配置',
                        color: const Color(0xFF4CAF50),
                        onPressed: _importConfig,
                        isFullWidth: true,
                      ),
                    ],
                  )
                else
                  // 桌面端：水平布局
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.photo_library_rounded,
                          label: '从相册选择',
                          color: const Color(0xFF6A5ACD),
                          onPressed: _pickImage,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.download_rounded,
                          label: '导入配置',
                          color: const Color(0xFF4CAF50),
                          onPressed: _importConfig,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  } // 构建操作按钮

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool isFullWidth = false,
  }) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, -3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建返回主页按钮
  Widget _buildHomeButton(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Container(
      width: isSmallScreen ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6A5ACD).withOpacity(0.3),
          width: 2,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFF6A5ACD).withOpacity(0.05),
          ],
        ),
      ),
      child: OutlinedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF6A5ACD),
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 40,
            vertical: isSmallScreen ? 16 : 15,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: isSmallScreen ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_rounded, size: 20),
            const SizedBox(width: 10),
            const Text(
              '返回主页',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // 图片预览部分按钮
  // 难度选择按钮、预览切换按钮、保存按钮

  // 构建难度选择器
  Widget _buildDifficultySelector() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 20 : 32,
        vertical: 24,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6A5ACD).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A5ACD).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A5ACD).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: const Color(0xFF6A5ACD),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '难度选择',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D2B55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          isSmallScreen
              ? Column(
                  children: [
                    _buildDifficultyButton(3, '简单 (3x3)', Icons.star_outline),
                    const SizedBox(height: 12),
                    _buildDifficultyButton(4, '中等 (4x4)', Icons.stars),
                    const SizedBox(height: 12),
                    _buildDifficultyButton(5, '困难 (5x5)', Icons.star_rate),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                        child: _buildDifficultyButton(
                            3, '简单', Icons.star_outline)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildDifficultyButton(4, '中等', Icons.stars)),
                    const SizedBox(width: 16),
                    Expanded(
                        child:
                            _buildDifficultyButton(5, '困难', Icons.star_rate)),
                  ],
                ),
        ],
      ),
    );
  }

  // 构建难度选择按钮
  Widget _buildDifficultyButton(int size, String label, [IconData? icon]) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isSelected = _gridSize == size;

    return Container(
      height: isSmallScreen ? 52 : 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF6A5ACD),
                  const Color(0xFF6A5ACD).withOpacity(0.8),
                ],
              )
            : null,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF6A5ACD).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: () => _updateGridSize(size),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.transparent : Colors.white,
          foregroundColor: isSelected ? Colors.white : const Color(0xFF2D2B55),
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : 12,
            vertical: 8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: isSelected ? Colors.white : const Color(0xFF6A5ACD),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建预览切换按钮
  Widget _buildPreviewToggleButton() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Container(
      width: isSmallScreen ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.3),
          width: 4,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            const Color(0xFFE91E63).withOpacity(0.05),
          ],
        ),
      ),
      child: OutlinedButton.icon(
        onPressed: _togglePreview,
        icon: Icon(_showPreview
            ? Icons.visibility_off_rounded
            : Icons.visibility_rounded),
        label: Text(_showPreview ? '隐藏预览' : '显示预览'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE91E63),
          backgroundColor: Colors.transparent,
          side: BorderSide.none,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 32 : 40,
            vertical: isSmallScreen ? 32 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // 构建保存按钮
  Widget _buildSaveButton() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final isSaved = _savedImagePath != null;
    final canSave = _selectedImage != null && _savedImagePath == null;

    return Container(
      width: isSmallScreen ? double.infinity : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: canSave || isSaved
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSaved
                    ? [
                        Colors.green,
                        Colors.green.withOpacity(0.8),
                      ]
                    : [
                        const Color(0xFFFF9800),
                        const Color(0xFFFF9800).withOpacity(0.8),
                      ],
              )
            : null,
        boxShadow: canSave || isSaved
            ? [
                BoxShadow(
                  color: (isSaved ? Colors.green : const Color(0xFFFF9800))
                      .withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ElevatedButton.icon(
        onPressed: canSave ? _saveImageAndConfig : null,
        icon: Icon(isSaved ? Icons.check_circle_rounded : Icons.save_rounded),
        label: Text(isSaved ? '已保存' : '保存图片和配置'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              canSave || isSaved ? Colors.transparent : Colors.grey.shade300,
          foregroundColor:
              canSave || isSaved ? Colors.white : Colors.grey.shade600,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 32 : 40,
            vertical: isSmallScreen ? 32 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // 以下为工具函数

  // 从相册选择图片（仅选择，不自动保存）
  // 仅得到_selectedImage,_savedImagePath = null
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _savedImagePath = null; // 重置保存路径
        _showPreview = false;
      });
    }
  }

  // 手动保存图片和创建配置文件
  Future<void> _saveImageAndConfig() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一张图片'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final savedPath = await _saveImageToAssets(_selectedImage!);

      setState(() {
        _savedImagePath = savedPath;
      });

      // 创建配置文件
      await _createConfigFile();

      // 显示保存成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片和配置已保存'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // 显示保存失败提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 保存图片到${appDir.path}/diyImages目录
  Future<String> _saveImageToAssets(File sourceFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'diyImages'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    // 获取当前时间戳作为文件名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourceFile.path);
    final fileName = 'diy_image_$timestamp$extension';

    final targetPath = path.join(imagesDir.path, fileName);

    // 复制文件
    await sourceFile.copy(targetPath);

    // 返回保存路径
    return targetPath;
  }

  // 创建配置文件
  Future<void> _createConfigFile() async {
    if (_savedImagePath == null) return;

    // 得到文件路径
    final appDir = await getApplicationDocumentsDirectory();
    final configDir = Directory(path.join(appDir.path, 'configs'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final configFileName = 'diyPuzzleConf$timestamp.json';

    final configPath = path.join(configDir.path, configFileName);
    final configFile = File(configPath);

    // 创建配置数据
    final configData = {
      'createdAt': DateTime.now().toIso8601String(),
      'imagePath': _savedImagePath,
      'difficulty': _mapGridSizeToDifficulty(_gridSize),
    };

    await configFile.writeAsString(json.encode(configData));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配置文件已创建\n保存路径: $configPath'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 4), // 增加显示时间以便用户看到完整路径
        ),
      );
    }
  }

  // 构建拼图预览
  Widget _buildPuzzlePreview() {
    if (_previewPieces == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridSize,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _gridSize * _gridSize,
      itemBuilder: (context, index) {
        final piece = _previewPieces![index];
        return RawImage(image: piece.image);
      },
    );
  }

  // 显示拼图预览
  void _togglePreview() async {
    if (!_showPreview) {
      // 如果要显示预览，先生成拼图块
      if (_selectedImage != null) {
        // 调用拼图生成函数
        final generator = PuzzleGenerateService();
        final pieces = await generator.generatePuzzle(
          _selectedImage!.path,
          _mapGridSizeToDifficulty(_gridSize),
        );
        // 更新状态
        setState(() {
          _previewPieces = pieces;
          _showPreview = true;
        });
      }
    } else {
      // 如果要隐藏预览，直接更新状态
      setState(() {
        _showPreview = false;
      });
    }
  }

  // 获取难度文本
  String _getDifficultyText() {
    switch (_gridSize) {
      case 3:
        return '简单';
      case 4:
        return '中等';
      case 5:
        return '困难';
      default:
        return '未知';
    }
  }

  // 将网格大小映射到难度等级
  int _mapGridSizeToDifficulty(int gridSize) {
    switch (gridSize) {
      case 3:
        return 1; // 简单
      case 4:
        return 2; // 中等
      case 5:
        return 3; // 困难
      default:
        return 1; // 默认为简单
    }
  }

  // 将网格大小映射到难度等级
  int _mapDifficultToGridSize(int difficulty) {
    switch (difficulty) {
      case 1:
        return 3; // 简单
      case 2:
        return 4; // 中等
      case 3:
        return 5; // 困难
      default:
        return 3; // 默认为简单
    }
  }

  // 调整网格大小
  void _updateGridSize(int size) {
    setState(() {
      _gridSize = size;
      // 如果当前正在显示预览，则需要重新生成拼图块
      if (_showPreview) {
        // 先隐藏，再重新生成并显示
        _showPreview = false;
        _togglePreview();
      }
    });
  }

  // 导入配置
  Future<void> _importConfig() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '选择要导入的配置文件',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final pathStr = result.files.first.path;
    if (pathStr == null) return;
    try {
      final content = await File(pathStr).readAsString();
      final data = json.decode(content);

      if (data is! Map || !data.containsKey('difficulty')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('配置文件格式不正确'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      // 读取数据
      final importedDiffculty = (data['difficulty'] is int)
          ? data['difficulty']
          : int.parse(data['difficulty'].toString());
      final importedGridSize = _mapDifficultToGridSize(importedDiffculty);
      final importedImagePath = data['imagePath'] as String?;

      // 验证图片路径是否在允许的目录内
      File? validImageFile;
      if (importedImagePath != null && importedImagePath.isNotEmpty) {
        // 验证图片文件是否存在
        final imageFile = File(importedImagePath);
        if (await imageFile.exists()) {
          validImageFile = imageFile;
        }
      }

      // 如果图片路径存在但文件不存在，询问是否重新选择
      if (importedImagePath != null &&
          importedImagePath.isNotEmpty &&
          validImageFile == null) {
        if (mounted) {
          final pick = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('图片未找到'),
              content: const Text('配置中引用的图片不存在，是否现在从相册选择图片以完成导入？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('选择图片'),
                ),
              ],
            ),
          );
          if (pick == true) {
            await _pickImage();
          }
        }
        return; // 不更新状态，等待用户操作
      }

      // 更新状态并刷新UI
      setState(() {
        _gridSize = importedGridSize;
        if (validImageFile != null) {
          _selectedImage = validImageFile;
          _savedImagePath = null;
        }
        _showPreview = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// 拼图块绘制类
class _PuzzlePiecePainter extends CustomPainter {
  final Color color;

  _PuzzlePiecePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    // 绘制拼图凹凸形状
    _drawPuzzleTab(canvas, center, radius, 0); // 上
    _drawPuzzleTab(canvas, center, radius, 1); // 右
    _drawPuzzleTab(canvas, center, radius, 2); // 下
    _drawPuzzleTab(canvas, center, radius, 3); // 左
  }

  void _drawPuzzleTab(Canvas canvas, Offset center, double radius, int side) {
    final path = Path();
    final tabWidth = radius / 2;

    switch (side) {
      case 0: // 上
        path.moveTo(center.dx - tabWidth, center.dy - radius);
        path.quadraticBezierTo(center.dx, center.dy - radius - tabWidth,
            center.dx + tabWidth, center.dy - radius);
        break;
      case 1: // 右
        path.moveTo(center.dx + radius, center.dy - tabWidth);
        path.quadraticBezierTo(center.dx + radius + tabWidth, center.dy,
            center.dx + radius, center.dy + tabWidth);
        break;
      case 2: // 下
        path.moveTo(center.dx + tabWidth, center.dy + radius);
        path.quadraticBezierTo(center.dx, center.dy + radius + tabWidth,
            center.dx - tabWidth, center.dy + radius);
        break;
      case 3: // 左
        path.moveTo(center.dx - radius, center.dy + tabWidth);
        path.quadraticBezierTo(center.dx - radius - tabWidth, center.dy,
            center.dx - radius, center.dy - tabWidth);
        break;
    }

    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
