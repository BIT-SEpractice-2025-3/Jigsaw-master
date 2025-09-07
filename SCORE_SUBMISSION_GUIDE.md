# 游戏分数提交功能

## 功能概述

拼图游戏现在支持在游戏完成后提交分数到服务器排行榜。支持经典拼图和大师模式两种游戏类型。

## 主要功能

### 1. 手动提交分数
- 游戏完成后显示完成对话框
- 点击"提交分数"按钮手动提交
- 显示详细的提交结果反馈

### 2. 自动提交分数（可选）
- 在设置中启用自动提交
- 游戏完成后自动提交分数
- 无需手动操作

### 3. 分数验证
- 自动验证用户登录状态
- 未登录时提示用户登录
- 网络错误时提供重试选项

## 使用方法

### 经典拼图模式

1. **开始游戏**：
   ```dart
   // 游戏正常进行
   ```

2. **游戏完成**：
   - 显示完成对话框
   - 显示用时和得分

3. **提交分数**：
   - 点击"提交分数"按钮
   - 或在设置中启用自动提交

### 大师模式

1. **开始游戏**：
   ```dart
   // 大师模式游戏
   ```

2. **游戏完成**：
   - 显示完成对话框
   - 显示用时和大师模式得分

3. **提交分数**：
   - 点击"提交分数"按钮
   - 分数包含吸附奖励和时间奖励

### 设置自动提交

1. **进入设置页面**：
   ```dart
   Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage()));
   ```

2. **启用自动提交**：
   - 找到"分数设置"部分
   - 开启"自动提交分数"开关

## 技术实现

### 核心类

#### ScoreSubmissionHelper
```dart
class ScoreSubmissionHelper {
  // 手动提交分数
  static Future<void> submitGameScore({
    required BuildContext context,
    required int score,
    required int timeInSeconds,
    required String difficulty,
  }) async

  // 自动提交分数
  static Future<void> submitGameScoreAuto({
    required BuildContext context,
    required int score,
    required int timeInSeconds,
    required String difficulty,
    required bool autoSubmit,
  }) async
}
```

#### AuthService
```dart
class AuthService {
  // 提交分数到服务器
  Future<void> submitScore(int score, int time, String difficulty) async
}
```

### 分数计算

#### 经典模式分数
```dart
int calculateScore() {
  int baseScore = 1000;           // 基础分数
  int timePenalty = time * 10;    // 时间惩罚
  int difficultyBonus = difficulty * 200; // 难度奖励
  return baseScore - timePenalty + difficultyBonus;
}
```

#### 大师模式分数
```dart
// 包含吸附奖励和时间奖励
int masterScore = baseSnapScore + timeBonus + efficiencyBonus;
```

## 服务器API

### 提交分数
```http
POST /api/scores
Authorization: Bearer <token>
Content-Type: application/json

{
  "score": 1250,
  "time": 180,
  "difficulty": "medium"
}
```

### 获取排行榜
```http
GET /api/scores
Authorization: Bearer <token>
```

## 错误处理

### 常见错误

1. **未登录**：
   - 显示登录提示
   - 提供登录按钮

2. **网络错误**：
   - 显示重试选项
   - 提供错误详情

3. **服务器错误**：
   - 显示友好错误信息
   - 建议稍后重试

### 错误反馈

```dart
// 成功反馈
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('分数提交成功！得分: $score'),
    backgroundColor: Colors.green,
    action: SnackBarAction(
      label: '查看排行榜',
      onPressed: () => Navigator.pushNamed(context, '/leaderboard'),
    ),
  ),
);

// 错误反馈
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('分数提交失败: $error'),
    backgroundColor: Colors.red,
    action: SnackBarAction(
      label: '重试',
      onPressed: () => retrySubmit(),
    ),
  ),
);
```

## 扩展功能

### 未来计划

1. **分数历史**：
   - 查看个人历史分数
   - 分数趋势图表

2. **成就系统**：
   - 游戏完成成就
   - 时间挑战成就

3. **排行榜优化**：
   - 按难度分类排行
   - 好友排行榜

4. **分数验证**：
   - 防止分数作弊
   - 服务器端验证

## 调试信息

### 日志输出
```
AuthService: isLoggedIn = true, user = testuser
AuthService: 保存用户数据到内存 - testuser
分数提交成功！得分: 1250
```

### 调试模式
```dart
// 启用详细日志
debugPrint('分数提交详情: score=$score, time=$time, difficulty=$difficulty');
```

## 注意事项

1. **网络依赖**：需要网络连接才能提交分数
2. **登录要求**：必须登录才能提交分数
3. **分数验证**：服务器会验证分数合理性
4. **重试机制**：网络错误时提供重试选项

## 总结

分数提交功能为游戏增加了竞技性和持久性，让玩家可以：
- ✅ 比较自己的游戏表现
- ✅ 参与排行榜竞争
- ✅ 保存游戏成就
- ✅ 享受游戏的长期乐趣