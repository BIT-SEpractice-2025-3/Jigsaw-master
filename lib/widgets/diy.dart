//自定义拼图界面
//->主页
//->开始游戏页面
import 'package:flutter/material.dart'; // 导入Flutter的材料设计库
import 'package:image_picker/image_picker.dart'; // 导入图片选择器
import 'dart:io'; // 导入IO库，用于处理文件
import 'dart:convert'; // 导入JSON处理库
import 'package:path/path.dart' as path; // 导入路径处理库
import 'home.dart';
import 'puzzle.dart';
import '../services/puzzle_generate_service.dart';
import '../models/puzzle_piece.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  List<PuzzlePiece>? _previewPieces; // 用于存储预览拼图块
  String? _savedImagePath; // 保存的图片路径
  bool _isGeneratingPreview = false;

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
            // 预览图片（如果有已选择或已保存的图片）
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
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _showPreview
              ? _buildPuzzlePreview()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Builder(builder: (context) {
                    // 优先显示 _selectedImage；否则显示 _savedImagePath（支持 assets 或 文件路径）
                    if (_selectedImage != null) {
                      return Image.file(_selectedImage!, fit: BoxFit.fill);
                    }
                    if (_savedImagePath != null) {
                      if (_savedImagePath!.startsWith('assets/')) {
                        return Image.asset(_savedImagePath!, fit: BoxFit.fill);
                      } else {
                        return Image.file(File(_savedImagePath!),
                            fit: BoxFit.fill);
                      }
                    }
                    return const SizedBox.shrink();
                  }),
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
      onPressed: _selectedImage != null || _savedImagePath != null
          ? () async {
              // 这里将来实现开始拼图的逻辑
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

  // 从相册选择图片（仅选择，不自动保存）
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _savedImagePath = null; // 重置保存路径
        _showPreview = false;
      });

      // 显示图片选择成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片已选择，点击保存按钮进行保存'),
            backgroundColor: Colors.blue,
          ),
        );
      }
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
      // 保存图片到assets/images/diyImages目录
      final savedPath = await _saveImageToAssets(_selectedImage!);

      setState(() {
        _savedImagePath = savedPath;
      });

      // 创建配置文件
      await _createConfigFile();

      // 显示保存成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('图片和配置已保存\n图片路径: $savedPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
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

  // 保存图片到assets/images/diyImages目录
  Future<String> _saveImageToAssets(File sourceFile) async {
    // 获取当前时间戳作为文件名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourceFile.path);
    final fileName = 'diy_image_$timestamp$extension';

    // 创建目标路径
    final assetsDir = Directory('assets/images/diyImages');
    if (!await assetsDir.exists()) {
      await assetsDir.create(recursive: true);
    }

    final targetPath = path.join(assetsDir.path, fileName);

    // 复制文件
    await sourceFile.copy(targetPath);

    // 返回相对路径（用于assets配置）
    return 'assets/images/diyImages/$fileName';
  }

  // 创建配置文件
  Future<void> _createConfigFile() async {
    if (_savedImagePath == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final configFileName = 'diyPuzzleConf$timestamp.json';

    // 创建配置数据
    final configData = {
      'createdAt': DateTime.now().toIso8601String(),
      'imagePath': _savedImagePath,
      'difficulty': _mapGridSizeToDifficulty(_gridSize),
      'gridSize': _gridSize,
      'difficultyText': _getDifficultyText(),
    };

    // 创建配置文件目录
    final configDir = Directory('assets/configs');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    // 保存配置文件
    final configPath = path.join(configDir.path, configFileName);
    final configFile = File(configPath);
    await configFile.writeAsString(json.encode(configData));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('配置文件已创建: $configFileName'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  // 显示拼图预览
  void _togglePreview() async {
    // 避免重复点击
    if (_isGeneratingPreview) return;

    // 决定使用哪个图片路径：优先使用已保存路径，否则使用临时选择的图片
    final imagePath = _savedImagePath ?? _selectedImage?.path;
    if (imagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('请先选择或导入图片'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!_showPreview) {
      setState(() {
        _isGeneratingPreview = true;
      });
      try {
        final generator = PuzzleGenerateService();
        final pieces = await generator.generatePuzzle(
          imagePath,
          _mapGridSizeToDifficulty(_gridSize),
        );
        if (mounted) {
          setState(() {
            _previewPieces = pieces;
            _showPreview = true;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('生成预览失败: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isGeneratingPreview = false;
          });
        }
      }
    } else {
      // 隐藏预览
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
    if (_previewPieces == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      clipBehavior: Clip.hardEdge,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _gridSize,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _gridSize * _gridSize,
      itemBuilder: (context, index) {
        final piece = _previewPieces![index];
        // 将 ui.Image 等比缩放/裁切到单元格内，避免原始图片尺寸导致溢出和重叠。
        return LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.zero,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: piece.image.width.toDouble(),
                      height: piece.image.height.toDouble(),
                      child: RawImage(image: piece.image),
                    ),
                  ),
                ),
              ),
            );
          },
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
    final hasImage = _selectedImage != null || _savedImagePath != null;
    return OutlinedButton.icon(
      onPressed: hasImage && !_isGeneratingPreview ? _togglePreview : null,
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

  // 构建导入/导出配置按钮组
  Widget _buildImportButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _importConfig,
          icon: const Icon(Icons.download),
          label: const Text('导入配置'),
        ),
      ],
    );
  }

  // 构建图片选择按钮
  Widget _buildImageSelectionButton() {
    return Column(
      children: [
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
            const SizedBox(width: 12),
            // 导入按钮
            _buildImportButtons(),
          ],
        ),
      ],
    );
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

      if (data is! Map || !data.containsKey('gridSize')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('配置文件格式不正确'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final importedGridSize = (data['gridSize'] is int)
          ? data['gridSize']
          : int.parse(data['gridSize'].toString());
      final importedImagePath = data['imagePath'] as String?;

      // 验证图片存在性（如果有 imagePath）
      bool imageExists = true;
      if (importedImagePath != null && importedImagePath.isNotEmpty) {
        if (importedImagePath.startsWith('assets/')) {
          // 首先检查项目目录下是否有该文件（例如刚刚保存到 assets/images/diyImages）
          final candidate =
              File(path.join(Directory.current.path, importedImagePath));
          if (await candidate.exists()) {
            imageExists = true;
            // 将 importedImagePath 替换为磁盘绝对路径，便于立即显示
          } else {
            // 如果磁盘不存在，再尝试 rootBundle（只有打包或重启后 asset 可用）
            try {
              await rootBundle.load(importedImagePath);
              imageExists = true;
            } catch (e) {
              imageExists = false;
            }
          }
        } else {
          final f = File(importedImagePath);
          imageExists = await f.exists();
        }
      }

      if (!imageExists) {
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
        if (importedImagePath != null && importedImagePath.isNotEmpty) {
          if (importedImagePath.startsWith('assets/')) {
            // 优先使用磁盘上的同名文件（如果存在），否则保留 assets 路径
            final candidatePath =
                path.join(Directory.current.path, importedImagePath);
            final candidate = File(candidatePath);
            if (candidate.existsSync()) {
              _selectedImage = candidate;
              _savedImagePath = null;
            } else {
              // 运行时不可访问的 assets，仅在下次重启或打包后可用
              _savedImagePath = importedImagePath;
              _selectedImage = null;
            }
          } else {
            final f = File(importedImagePath);
            if (f.existsSync()) {
              _selectedImage = f;
              _savedImagePath = null;
            } else {
              _savedImagePath = importedImagePath;
              _selectedImage = null;
            }
          }
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
