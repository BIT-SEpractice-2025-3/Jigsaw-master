//自定义拼图界面
//->主页
import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'package:image_picker/image_picker.dart'; // 导入图片选择器
import 'dart:io'; // 导入IO库，用于处理文件
import 'home.dart';

class DiyPage extends StatefulWidget {
  const DiyPage({super.key});

  @override
  State<DiyPage> createState() => _DiyPageState();
}

class _DiyPageState extends State<DiyPage> {
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _showPreview = false;
  int _gridSize = 3; // 默认3x3网格

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("自定义拼图"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 预览图片
            if (_selectedImage != null) _buildImagePreviewSection(),
            // 图片选择按钮
            _buildImageSelectionButton(),
            // 开始游戏按钮
            if (_selectedImage != null) ...[
              const SizedBox(height: 20),
              _buildStartPuzzleButton(context),
            ],
            const SizedBox(height: 40),
            // 返回主页按钮
            _buildHomeButton(context),
          ],
        ),
      ),
    );
  }

  // 构建图片预览部分
  Widget _buildImagePreviewSection() {
    return Column(
      children: [
        Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _showPreview
              ? _buildPuzzlePreview()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  ),
                ),
        ),
        const SizedBox(height: 15),
        // 难度选择
        _buildDifficultySelector(),
        const SizedBox(height: 15),
        // 预览切换按钮
        _buildPreviewToggleButton(),
        const SizedBox(height: 20),
      ],
    );
  }

  // 构建开始拼图按钮
  Widget _buildStartPuzzleButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        if (_selectedImage != null) {
          // 这里将来实现开始拼图的逻辑
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '开始${_gridSize}x${_gridSize}拼图，难度：${_getDifficultyText()}'),
              backgroundColor: Colors.green,
            ),
          );
          // 这里可以跳转到拼图游戏页面，并传入图片和网格大小
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => PuzzlePage(
          //       image: _selectedImage!,
          //       gridSize: _gridSize,
          //     ),
          //   ),
          // );
        }
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('开始拼图', style: TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }

  // 构建返回主页按钮
  Widget _buildHomeButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
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
          Icon(Icons.home),
          SizedBox(width: 10),
          Text('返回主页', style: TextStyle(fontSize: 18)),
        ],
      ),
    );
  }

  // 从相册选择图片
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _showPreview = false;
      });
    }
  }

  // 显示拼图预览
  void _togglePreview() {
    setState(() {
      _showPreview = !_showPreview;
    });
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

  // 调整网格大小
  void _updateGridSize(int size) {
    setState(() {
      _gridSize = size;
      if (_showPreview) {
        // 如果正在预览，更新预览
        _showPreview = true;
      }
    });
  }

  // 构建难度选择按钮
  Widget _buildDifficultyButton(int size, String label) {
    return ElevatedButton(
      onPressed: () => _updateGridSize(size),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gridSize == size ? Colors.blue : Colors.grey.shade300,
        foregroundColor: _gridSize == size ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label),
    );
  }

  // 构建拼图预览
  Widget _buildPuzzlePreview() {
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
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: ClipRect(
            child: FractionalTranslation(
              translation: Offset(
                -(index % _gridSize) / (_gridSize - 1),
                -(index ~/ _gridSize) / (_gridSize - 1),
              ),
              child: SizedBox(
                width: 250.0 * _gridSize,
                height: 250.0 * _gridSize,
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 构建难度选择器
  Widget _buildDifficultySelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('难度: ', style: TextStyle(fontSize: 16)),
        _buildDifficultyButton(3, '简单'),
        const SizedBox(width: 10),
        _buildDifficultyButton(4, '中等'),
        const SizedBox(width: 10),
        _buildDifficultyButton(5, '困难'),
      ],
    );
  }

  // 构建预览切换按钮
  Widget _buildPreviewToggleButton() {
    return OutlinedButton.icon(
      onPressed: _togglePreview,
      icon: Icon(_showPreview ? Icons.visibility_off : Icons.visibility),
      label: Text(_showPreview ? '隐藏预览' : '显示预览'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.purple,
      ),
    );
  }

  // 构建图片选择按钮
  Widget _buildImageSelectionButton() {
    return Column(
      children: [
        const Text("选择一张图片开始拼图",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('从相册选择'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
