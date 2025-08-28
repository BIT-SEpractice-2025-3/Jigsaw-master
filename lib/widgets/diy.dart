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
    return Scaffold(
      appBar: AppBar(
        title: const Text("自定义拼图"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 预览图片
            if (_selectedImage != null || _savedImagePath != null)
              _buildImagePreviewSection(),
            // 图片选择按钮
            _buildImageSelectionButton(),
            // 开始游戏按钮
            if (_selectedImage != null || _savedImagePath != null) ...[
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
            border: Border.all(color: Colors.grey, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // 如果正在展示预览，显示图片
            // 否则构建预览
            child: _showPreview
                ? _buildPuzzlePreview()
                : (_selectedImage != null
                    ? Image.file(
                        _selectedImage!,
                        width: 246,
                        height: 246,
                        fit: BoxFit.contain,
                      )
                    : (_savedImagePath != null
                        ? Image.asset(
                            _savedImagePath!,
                            width: 246,
                            height: 246,
                            fit: BoxFit.contain,
                          )
                        : Container())),
          ),
        ),
        const SizedBox(height: 15),
        // 难度选择
        _buildDifficultySelector(),
        const SizedBox(height: 15),
        // 预览切换按钮
        _buildPreviewToggleButton(),
        const SizedBox(height: 15),
        // 保存按钮
        _buildSaveButton(),
        const SizedBox(height: 20),
      ],
    );
  }

  // 构建开始拼图按钮
  Widget _buildStartPuzzleButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _selectedImage != null
          ? () async {
              // 信息
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '开始${_gridSize}x$_gridSize拼图，难度：${_getDifficultyText()}'),
                  backgroundColor: Colors.green,
                ),
              );

              // 跳转到拼图游戏页面，优先使用保存的路径，否则使用临时路径
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
      icon: const Icon(Icons.play_arrow),
      label: const Text('开始拼图', style: TextStyle(fontSize: 18)),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        backgroundColor: _selectedImage != null ? Colors.orange : Colors.grey,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade400,
        disabledForegroundColor: Colors.white,
      ),
    );
  }

  // 构建图片选择按钮
  Widget _buildImageSelectionButton() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图片选择按钮
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
            const SizedBox(width: 20),
            // 导入配置按钮
            ElevatedButton.icon(
              onPressed: _importConfig,
              icon: const Icon(Icons.download),
              label: const Text('导入配置'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
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

  // 图片预览部分按钮
  // 难度选择按钮、预览切换按钮、保存按钮

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

  // 构建保存按钮
  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      onPressed: _selectedImage != null && _savedImagePath == null
          ? _saveImageAndConfig
          : null,
      icon: Icon(_savedImagePath != null ? Icons.check : Icons.save),
      label: Text(_savedImagePath != null ? '已保存' : '保存图片和配置'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        backgroundColor: _savedImagePath != null ? Colors.green : Colors.purple,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey,
        disabledForegroundColor: Colors.white,
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
