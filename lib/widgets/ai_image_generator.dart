import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'game_select.dart';
import 'package:path/path.dart' as path;

class AIImageGeneratorPage extends StatefulWidget {
  const AIImageGeneratorPage({super.key});

  @override
  State<AIImageGeneratorPage> createState() => _AIImageGeneratorPageState();
}

class _AIImageGeneratorPageState extends State<AIImageGeneratorPage> {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _negativePromptController =
      TextEditingController();
  bool _isGenerating = false;
  bool _isSaving = false;
  Uint8List? _generatedImageBytes;
  String? _errorMessage;
  String? _savedImagePath;

  @override
  void initState() {
    super.initState();
    // 预填充示例提示词
    _promptController.text =
        "A beautiful landscape with mountains and lake, digital art, 4k";
    _negativePromptController.text =
        "blurry, low quality, distorted, watermark";
  }

  Future<void> _loadDefaultImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/2.jpg');
      setState(() {
        _generatedImageBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      setState(() {
        _errorMessage = "加载默认图片失败: $e";
      });
    }
  }

  Future<void> _generateImage() async {
    if (_promptController.text.isEmpty) {
      setState(() {
        _errorMessage = "请输入提示词";
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedImageBytes = null;
      _errorMessage = null;
      _savedImagePath = null;
    });

    try {
      // const String path =
      //     "https://api.stability.ai/v1/generation/stable-diffusion-xl-1024-v1-0/text-to-image";

      // final Map<String, String> headers = {
      //   'Accept': 'application/json',
      //   'Authorization': 'Bearer $_apiKey',
      //   'Content-Type': 'application/json',
      // };

      // final Map<String, dynamic> body = {
      //   'steps': 40,
      //   'width': 1024,
      //   'height': 1024,
      //   'seed': 0,
      //   'cfg_scale': 5,
      //   'samples': 1,
      //   'text_prompts': [
      //     {'text': _promptController.text, 'weight': 1},
      //     if (_negativePromptController.text.isNotEmpty)
      //       {'text': _negativePromptController.text, 'weight': -1}
      //   ],
      // };

      // final response = await http.post(
      //   Uri.parse(path),
      //   headers: headers,
      //   body: json.encode(body),
      // );

      // if (response.statusCode == 200) {
      //   final Map<String, dynamic> responseData = json.decode(response.body);

      //   if (responseData['artifacts'] != null &&
      //       responseData['artifacts'].isNotEmpty) {
      //     final String base64Image = responseData['artifacts'][0]['base64'];
      //     final Uint8List bytes = base64.decode(base64Image);

      //     setState(() {
      //       _generatedImageBytes = bytes;
      //     });
      //   } else {
      //     setState(() {
      //       _errorMessage = "未生成图片，请重试";
      //     });
      //   }
      // } else {
      //   setState(() {
      //     _errorMessage =
      //         "API调用失败 (${response.statusCode}): ${response.reasonPhrase}";
      //   });
      // }
      _loadDefaultImage();
    } catch (e) {
      setState(() {
        _errorMessage = "发生错误: $e";
      });
    } finally { 
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<String> _saveImageToAssets() async {
    if (_generatedImageBytes == null) return '';

    setState(() {
      _isSaving = true;
    });

    try {
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'assets/ai'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // 获取当前时间戳作为文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ai_image_$timestamp.png';
      final targetPath = path.join(imagesDir.path, fileName);

      // 保存图片文件
      final File file = File(targetPath);
      await file.writeAsBytes(_generatedImageBytes!);

      // 返回保存路径
      return targetPath;
    } catch (e) {
      setState(() {
        _errorMessage = "保存图片失败: $e";
      });
      return '';
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _useImageForPuzzle() {
    if (_savedImagePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先生成并保存图片')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameSelectionPage(imagePath: _savedImagePath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // 与其他页面保持一致：顶部显示返回按钮
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          _buildBackgroundPuzzleElements(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Column(
                    children: [
                      SizedBox(height: 100),
                      Icon(
                        Icons.auto_awesome,
                        size: 70,
                        color: Color(0xFF6A5ACD),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'AI生成拼图图片',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D2B55),
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 4.0,
                              color: Colors.black12,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '用AI创造独特的拼图体验',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      SizedBox(height: 40),
                    ],
                  ),

                  // 提示词输入区域
                  _buildInputField(
                    controller: _promptController,
                    label: '正面提示词',
                    hint: '描述你想要的图片内容...',
                    icon: Icons.lightbulb_outline,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _negativePromptController,
                    label: '负面提示词 (可选)',
                    hint: '描述你不想要的内容...',
                    icon: Icons.block,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // 生成按钮
                  _buildMenuButton(
                    context: context,
                    icon: Icons.auto_awesome,
                    title: '生成图片',
                    subtitle: '根据提示词创建AI图像',
                    color: const Color(0xFF6A5ACD),
                    isLoading: _isGenerating,
                    onPressed: _generateImage,
                  ),
                  const SizedBox(height: 16),

                  // 错误信息
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red[400]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 图片显示区域
                  if (_generatedImageBytes != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      '生成的图片:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2B55),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _generatedImageBytes!,
                          fit: BoxFit.contain,
                          height: 300,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 保存和使用按钮
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            text: '保存图片',
                            icon: Icons.save,
                            color: const Color(0xFF6A5ACD),
                            isLoading: _isSaving,
                            onPressed: () async {
                              final savedPath = await _saveImageToAssets();
                              if (savedPath.isNotEmpty) {
                                setState(() {
                                  _savedImagePath = savedPath;
                                });

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('图片已保存为: $savedPath'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionButton(
                            text: '使用图片拼图',
                            icon: Icons.extension,
                            color: const Color(0xFF4CAF50),
                            onPressed: _savedImagePath != null
                                ? _useImageForPuzzle
                                : null,
                          ),
                        ),
                      ],
                    ),

                    if (_savedImagePath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          '已保存: ${_savedImagePath!.split('/').last}',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],

                  // 提示信息
                  if (_generatedImageBytes == null && !_isGenerating)
                    Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Column(
                        children: [
                          Icon(Icons.auto_awesome_mosaic,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            '输入提示词生成自定义拼图图片',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundPuzzleElements(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
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
        Positioned(
          top: -30,
          left: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x4D6A5ACD),
            size: 150,
            rotation: 0.2,
          ),
        ),
        Positioned(
          top: 50,
          right: -40,
          child: _buildPuzzleDecoration(
            color: const Color(0x4DE91E63),
            size: 120,
            rotation: -0.3,
          ),
        ),
        Positioned(
          bottom: 80,
          left: -50,
          child: _buildPuzzleDecoration(
            color: const Color(0x4DFF9800),
            size: 130,
            rotation: 0.7,
          ),
        ),
        Positioned(
          bottom: -40,
          right: -30,
          child: _buildPuzzleDecoration(
            color: const Color(0x4D4CAF50),
            size: 160,
            rotation: -0.5,
          ),
        ),
        Positioned(
          top: screenSize.height * 0.3,
          left: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x336A5ACD),
            size: 70,
            rotation: 0.1,
          ),
        ),
        Positioned(
          bottom: screenSize.height * 0.3,
          right: screenSize.width * 0.2,
          child: _buildPuzzleDecoration(
            color: const Color(0x33FF9800),
            size: 60,
            rotation: -0.2,
          ),
        ),
      ],
    );
  }

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

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, color: const Color(0xFF6A5ACD)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Color.fromRGBO(color.red, color.green, color.blue, 0.3),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Color.fromRGBO(color.red, color.green, color.blue, 0.2),
            width: 1,
          ),
        ),
        child: ListTile(
          onTap: isLoading ? null : onPressed,
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color.fromRGBO(color.red, color.green, color.blue, 0.15),
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? const CircularProgressIndicator(strokeWidth: 2)
                : Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          trailing: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color.fromRGBO(color.red, color.green, color.blue, 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              color: color,
              size: 16,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    super.dispose();
  }
}

class _PuzzlePiecePainter extends CustomPainter {
  final Color color;

  _PuzzlePiecePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 3;

    _drawPuzzleTab(canvas, center, radius, 0, paint);
    _drawPuzzleTab(canvas, center, radius, 1, paint);
    _drawPuzzleTab(canvas, center, radius, 2, paint);
    _drawPuzzleTab(canvas, center, radius, 3, paint);
  }

  void _drawPuzzleTab(
      Canvas canvas, Offset center, double radius, int side, Paint paint) {
    final path = Path();
    final tabWidth = radius / 2;

    switch (side) {
      case 0:
        path.moveTo(center.dx - tabWidth, center.dy - radius);
        path.quadraticBezierTo(
          center.dx,
          center.dy - radius - tabWidth,
          center.dx + tabWidth,
          center.dy - radius,
        );
        break;
      case 1:
        path.moveTo(center.dx + radius, center.dy - tabWidth);
        path.quadraticBezierTo(
          center.dx + radius + tabWidth,
          center.dy,
          center.dx + radius,
          center.dy + tabWidth,
        );
        break;
      case 2:
        path.moveTo(center.dx + tabWidth, center.dy + radius);
        path.quadraticBezierTo(
          center.dx,
          center.dy + radius + tabWidth,
          center.dx - tabWidth,
          center.dy + radius,
        );
        break;
      case 3:
        path.moveTo(center.dx - radius, center.dy + tabWidth);
        path.quadraticBezierTo(
          center.dx - radius - tabWidth,
          center.dy,
          center.dx - radius,
          center.dy - tabWidth,
        );
        break;
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
