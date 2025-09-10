import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _autoSubmitScore = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    final audioService = AudioService();
    if (!audioService.bgmPlaying) {
      audioService.playBgm();
    }
  }

  Future<void> _loadSettings() async {
    // 暂时使用内存存储，实际应用中可以使用文件存储
    // 这里可以从本地文件或数据库加载设置
    setState(() {
      _autoSubmitScore = false; // 默认关闭自动提交
      _soundEnabled = true;
      _vibrationEnabled = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.deepPurple.shade50,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // 分数设置
          _buildSectionHeader('分数设置'),
          _buildSwitchTile(
            title: '自动提交分数',
            subtitle: '游戏完成后自动提交分数到排行榜',
            value: _autoSubmitScore,
            onChanged: (value) {
              setState(() {
                _autoSubmitScore = value;
              });
              // 这里可以保存设置到本地存储
              print('自动提交分数设置: $value');
            },
          ),

          // 游戏设置
          _buildSectionHeader('游戏设置'),
          _buildSwitchTile(
            title: '音效',
            subtitle: '启用游戏音效',
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
              print('音效设置: $value');
            },
          ),
          _buildSwitchTile(
            title: '震动',
            subtitle: '启用游戏震动反馈',
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
              print('震动设置: $value');
            },
          ),

          // 关于
          _buildSectionHeader('关于'),
          const ListTile(
            title: const Text('版本'),
            subtitle: const Text('1.0.0'),
            trailing: const Icon(Icons.info_outline),
          ),
          const ListTile(
            title: const Text('开发者'),
            subtitle: const Text('拼图大师团队'),
            trailing: const Icon(Icons.people),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.deepPurple,
    );
  }
}
