import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/auth_service.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final String type;
  final Map<String, dynamic> condition;
  final int rewardPoints;
  final String category;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    required this.condition,
    required this.rewardPoints,
    required this.category,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      icon: json['icon'],
      type: json['type'],
      condition: json['condition'],
      rewardPoints: json['reward_points'],
      category: json['category'],
    );
  }
}

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();

  // 公共静态方法：供其他页面调用来检查和解锁成就
  static Future<void> checkAndUnlockAchievements(BuildContext context,
      {bool showDialog = true}) async {
    final authService = AuthService();
    if (!authService.isLoggedIn) return;

    try {
      // 加载成就数据
      final String achievementsJson =
          await rootBundle.loadString('assets/achievements.json');
      final Map<String, dynamic> data = json.decode(achievementsJson);
      final achievements = (data['achievements'] as List)
          .map((item) => Achievement.fromJson(item))
          .toList();

      // 获取用户成就完成情况
      final result = await authService.getUserAchievements();
      final completedAchievements = (result['completed_achievements'] as List)
          .map((item) => item['achievement_id'] as String)
          .toSet();
      final userStats = result['user_stats'];

      List<Achievement> newlyCompleted = [];

      for (final achievement in achievements) {
        // 如果成就条件满足但尚未在数据库中标记为完成
        if (!completedAchievements.contains(achievement.id) &&
            AchievementsPage._checkConditionStatic(achievement, userStats)) {
          try {
            await authService.unlockAchievement(achievement.id);
            newlyCompleted.add(achievement);
            print('自动解锁成就: ${achievement.title}');
          } catch (e) {
            print('解锁成就失败 ${achievement.id}: $e');
          }
        }
      }

      // 如果有新解锁的成就且需要显示弹窗，显示通知
      if (newlyCompleted.isNotEmpty && showDialog && context.mounted) {
        AchievementsPage._showUnlockedDialogStatic(context, newlyCompleted);
      }
    } catch (e) {
      print('检查成就失败: $e');
    }
  }

  // 静态方法：检查成就条件
  static bool _checkConditionStatic(
      Achievement achievement, Map<String, dynamic> userStats) {
    if (userStats.isEmpty) return false;

    try {
      final condition = achievement.condition;

      // 支持多条件AND逻辑
      return _evaluateConditionGroup(condition, userStats);
    } catch (e) {
      print('检查成就条件时出错: $e');
      return false;
    }
  }

  // 评估条件组（支持嵌套条件）
  static bool _evaluateConditionGroup(
      Map<String, dynamic> conditions, Map<String, dynamic> userStats) {
    // 检查是否有逻辑操作符
    if (conditions.containsKey('and')) {
      final List<dynamic> andConditions = conditions['and'];
      return andConditions
          .every((cond) => _evaluateConditionGroup(cond, userStats));
    }

    if (conditions.containsKey('or')) {
      final List<dynamic> orConditions = conditions['or'];
      return orConditions
          .any((cond) => _evaluateConditionGroup(cond, userStats));
    }

    // 评估单个条件
    return _evaluateSingleCondition(conditions, userStats);
  }

  // 评估单个条件
  static bool _evaluateSingleCondition(
      Map<String, dynamic> condition, Map<String, dynamic> userStats) {
    for (final entry in condition.entries) {
      final key = entry.key;
      final expectedValue = entry.value;

      // 跳过非数据字段
      if (['type', 'description'].contains(key)) continue;

      final actualValue = _toIntStatic(userStats[key]);

      // 支持不同的比较操作符
      if (expectedValue is Map<String, dynamic>) {
        for (final opEntry in expectedValue.entries) {
          final operator = opEntry.key;
          final compareValue = _toIntStatic(opEntry.value);

          switch (operator) {
            case '>=':
              if (actualValue < compareValue) return false;
              break;
            case '<=':
              if (actualValue > compareValue) return false;
              break;
            case '>':
              if (actualValue <= compareValue) return false;
              break;
            case '<':
              if (actualValue >= compareValue) return false;
              break;
            case '==':
              if (actualValue != compareValue) return false;
              break;
            case '!=':
              if (actualValue == compareValue) return false;
              break;
            default:
              print('不支持的操作符: $operator');
              return false;
          }
        }
      } else {
        // 默认使用 >= 操作符
        final compareValue = _toIntStatic(expectedValue);
        if (actualValue < compareValue) return false;
      }
    }

    return true;
  }

  // 静态方法：安全地将值转换为int
  static int _toIntStatic(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // 静态方法：显示解锁弹窗
  static void _showUnlockedDialogStatic(
      BuildContext context, List<Achievement> achievements) {
    if (achievements.length == 1) {
      final achievement = achievements.first;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 8),
              Text('成就解锁！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconDataStatic(achievement.icon),
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 16),
              Text(
                achievement.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(achievement.description),
              SizedBox(height: 8),
              Text(
                '+${achievement.rewardPoints} 积分',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    } else if (achievements.length > 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.emoji_events,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 8),
              Text('解锁了 ${achievements.length} 个成就！'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: achievements
                .map((achievement) => ListTile(
                      leading: Icon(_getIconDataStatic(achievement.icon)),
                      title: Text(achievement.title),
                      subtitle: Text('+${achievement.rewardPoints} 积分'),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 静态方法：获取图标
  static IconData _getIconDataStatic(String iconName) {
    switch (iconName) {
      case 'speed':
        return Icons.speed;
      case 'star':
        return Icons.star;
      case 'trending_up':
        return Icons.trending_up;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'flash_on':
        return Icons.flash_on;
      case 'flag':
        return Icons.flag;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'target':
        return Icons.gps_fixed;
      case 'timer':
        return Icons.timer;
      case 'people':
        return Icons.people;
      default:
        return Icons.extension;
    }
  }
}

class _AchievementsPageState extends State<AchievementsPage> {
  final AuthService _authService = AuthService();
  List<Achievement> _achievements = [];
  Set<String> _completedAchievements = {};
  Map<String, dynamic> _userStats = {};
  bool _isLoading = true;
  String _selectedCategory = 'all';

  final List<String> _categories = [
    'all',
    'speed',
    'skill',
    'progress',
    'endurance',
    'social'
  ];

  final Map<String, String> _categoryNames = {
    'all': '全部',
    'speed': '速度',
    'skill': '技巧',
    'progress': '进步',
    'endurance': '耐力',
    'social': '社交'
  };

  bool _isStatsCardHovered = false;
  int _hoveredCategoryIndex = -1;
  String? _hoveredAchievementId;
  bool _isLoginButtonHovered = false;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    try {
      // 加载成就数据
      final String achievementsJson =
          await rootBundle.loadString('assets/achievements.json');
      final Map<String, dynamic> data = json.decode(achievementsJson);

      setState(() {
        _achievements = (data['achievements'] as List)
            .map((item) => Achievement.fromJson(item))
            .toList();
      });

      // 如果已登录，获取用户成就完成情况
      if (_authService.isLoggedIn) {
        await _loadUserAchievements();
      }
    } catch (e) {
      print('加载成就数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载成就数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserAchievements() async {
    try {
      final result = await _authService.getUserAchievements();
      setState(() {
        _completedAchievements = (result['completed_achievements'] as List)
            .map((item) => item['achievement_id'] as String)
            .toSet();
        _userStats = result['user_stats'];
      });

      // 检查并自动解锁新完成的成就 (不显示弹窗，因为是页面初始化)
      await _checkAndUnlockAchievements(showDialog: false);
    } catch (e) {
      print('加载用户成就失败: $e');
    }
  }

  Future<void> _checkAndUnlockAchievements({bool showDialog = true}) async {
    if (!_authService.isLoggedIn || _achievements.isEmpty) return;

    List<Achievement> newlyCompleted = [];

    for (final achievement in _achievements) {
      // 如果成就条件满足但尚未在数据库中标记为完成
      if (!_completedAchievements.contains(achievement.id) &&
          _checkCondition(achievement, _userStats)) {
        try {
          await _authService.unlockAchievement(achievement.id);
          _completedAchievements.add(achievement.id);
          newlyCompleted.add(achievement);
          print('自动解锁成就: ${achievement.title}');
        } catch (e) {
          print('解锁成就失败 ${achievement.id}: $e');
        }
      }
    }

    // 如果有新解锁的成就，更新UI
    if (newlyCompleted.isNotEmpty && mounted) {
      setState(() {}); // 更新UI显示

      // 如果需要显示弹窗，使用静态方法显示
      if (showDialog) {
        _showUnlockedDialog(context, newlyCompleted);
      }
    }
  }

  bool _isAchievementCompleted(Achievement achievement) {
    if (!_authService.isLoggedIn) return false;

    // 检查是否已经在数据库中标记为完成
    if (_completedAchievements.contains(achievement.id)) {
      return true;
    }

    // 根据条件检查是否应该完成
    return _checkCondition(achievement, _userStats);
  }

  // 实例方法：检查成就条件 (复用静态方法逻辑)
  bool _checkCondition(
      Achievement achievement, Map<String, dynamic> userStats) {
    return AchievementsPage._checkConditionStatic(achievement, userStats);
  }

  // 实例方法：显示解锁弹窗 (复用静态方法逻辑)
  void _showUnlockedDialog(
      BuildContext context, List<Achievement> achievements) {
    AchievementsPage._showUnlockedDialogStatic(context, achievements);
  }

  List<Achievement> _getFilteredAchievements() {
    if (_selectedCategory == 'all') {
      return _achievements;
    }
    return _achievements.where((a) => a.category == _selectedCategory).toList();
  }

  int _getCompletedCount() {
    return _achievements.where((a) => _isAchievementCompleted(a)).length;
  }

  int _getTotalPoints() {
    return _achievements
        .where((a) => _isAchievementCompleted(a))
        .fold(0, (sum, a) => sum + a.rewardPoints);
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'speed':
        return Icons.speed;
      case 'star':
        return Icons.star;
      case 'trending_up':
        return Icons.trending_up;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'flash_on':
        return Icons.flash_on;
      case 'flag':
        return Icons.flag;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'target':
        return Icons.gps_fixed;
      case 'timer':
        return Icons.timer;
      case 'people':
        return Icons.people;
      default:
        return Icons.extension;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '成就系统',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D2B55),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF6A5ACD),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE8EAF6),
            ],
          ),
        ),
        child: Column(
          children: [
            // 统计信息顶部卡片
            if (!_isLoading && _authService.isLoggedIn) _buildStatsCard(),

            // 分类选择
            if (!_isLoading) _buildCategorySelector(),

            // 成就列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAchievementsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isStatsCardHovered = true),
      onExit: (_) => setState(() => _isStatsCardHovered = false),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isStatsCardHovered
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _isStatsCardHovered ? 15 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_getCompletedCount()}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A5ACD),
                    ),
                  ),
                  const Text(
                    '已完成',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_achievements.length}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2B55),
                    ),
                  ),
                  const Text(
                    '总成就',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              color: Colors.grey.shade300,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_getTotalPoints()}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF9800),
                    ),
                  ),
                  const Text(
                    '积分',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category == _selectedCategory;
          final isHovered = _hoveredCategoryIndex == index;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredCategoryIndex = index),
            onExit: (_) => setState(() => _hoveredCategoryIndex = -1),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6A5ACD)
                      : (isHovered ? Colors.grey.shade100 : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6A5ACD).withOpacity(0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    _categoryNames[category] ?? category,
                    style: TextStyle(
                      color:
                          isSelected ? Colors.white : const Color(0xFF6A5ACD),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAchievementsList() {
    if (!_authService.isLoggedIn) {
      return _buildLoginPrompt();
    }

    final filteredAchievements = _getFilteredAchievements();

    if (filteredAchievements.isEmpty) {
      return const Center(
        child: Text(
          '该分类下暂无成就',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredAchievements.length,
      itemBuilder: (context, index) {
        final achievement = filteredAchievements[index];
        final isCompleted = _isAchievementCompleted(achievement);

        return _buildAchievementCard(achievement, isCompleted);
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isCompleted) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredAchievementId = achievement.id),
      onExit: (_) => setState(() => _hoveredAchievementId = null),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF6A5ACD).withOpacity(0.3)
                : Colors.grey.shade200,
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _hoveredAchievementId == achievement.id
                  ? Colors.black.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: _hoveredAchievementId == achievement.id ? 12 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 成就图标
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFF6A5ACD).withOpacity(0.15)
                    : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(achievement.icon),
                color: isCompleted
                    ? const Color(0xFF6A5ACD)
                    : Colors.grey.shade400,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // 成就信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCompleted
                          ? const Color(0xFF2D2B55)
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    achievement.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.stars,
                        size: 16,
                        color: Colors.amber.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${achievement.rewardPoints} 积分',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 完成状态
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6A5ACD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '已完成',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(
                Icons.lock,
                color: Colors.grey.shade400,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            '请先登录查看成就',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '登录后可以查看您的成就进度',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 30),
          MouseRegion(
            onEnter: (_) => setState(() => _isLoginButtonHovered = true),
            onExit: (_) => setState(() => _isLoginButtonHovered = false),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLoginButtonHovered
                    ? const Color(0xFF5A4FCF)
                    : const Color(0xFF6A5ACD),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: _isLoginButtonHovered ? 8 : 2,
              ),
              child: const Text(
                '返回主页登录',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
