import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // 恢复http导入用于API调用
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // 添加json支持
import 'package:flutter/services.dart' show rootBundle; // 恢复rootBundle导入
import 'game_select.dart'; // 添加导入

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
    // 不再加载默认图片，使用API生成
  }

  Future<void> _loadDefaultImage() async {
    try {
      final ByteData data =
          await rootBundle.load('assets/images/2.jpg');
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

  // 修改保存方法，强制命名为1.png
  Future<void> _saveImageToAssets() async {
    if (_generatedImageBytes == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // 请求存储权限
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        setState(() {
          _errorMessage = "需要存储权限来保存图片";
        });
        return;
      }

      // 获取应用文档目录
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String assetsDirPath = '${appDocDir.path}/assets/ai';
      final Directory assetsDir = Directory(assetsDirPath);

      if (!await assetsDir.exists()) {
        await assetsDir.create(recursive: true);
      }

      // 强制命名为1.png
      final String fileName = '1.png';
      final String filePath = '${assetsDir.path}/$fileName';

      // 保存图片文件
      final File file = File(filePath);
      await file.writeAsBytes(_generatedImageBytes!);

      setState(() {
        _savedImagePath = filePath;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('图片已保存为: $filePath'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "保存图片失败: $e";
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // 使用生成的图片进入拼图游戏
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
      appBar: AppBar(
        title: const Text('AI生成拼图图片'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 提示词输入区域
              TextField(
                controller: _promptController,
                decoration: const InputDecoration(
                  labelText: '正面提示词',
                  hintText: '描述你想要的图片内容...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _negativePromptController,
                decoration: const InputDecoration(
                  labelText: '负面提示词 (可选)',
                  hintText: '描述你不想要的内容...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // 生成按钮
              ElevatedButton(
                onPressed: _isGenerating ? null : _generateImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isGenerating
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white))
                    : const Text('生成图片', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),

              // 错误信息
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // 图片显示区域
              if (_generatedImageBytes != null) ...[
                const SizedBox(height: 20),
                const Text(
                  '生成的图片:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.memory(
                    _generatedImageBytes!,
                    fit: BoxFit.contain,
                    height: 300,
                  ),
                ),
                // 保存和使用按钮
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveImageToAssets,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: _isSaving
                            ? const CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white))
                            : const Text('保存图片'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            _savedImagePath != null ? _useImageForPuzzle : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('使用图片拼图'),
                      ),
                    ),
                  ],
                ),

                if (_savedImagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '已保存: ${_savedImagePath!.split('/').last}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],

              // 提示信息
              if (_generatedImageBytes == null && !_isGenerating)
                const Padding(
                  padding: EdgeInsets.only(top: 40.0),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '输入提示词生成自定义拼图图片',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
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
