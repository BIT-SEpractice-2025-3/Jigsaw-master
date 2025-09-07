# Flutter客户端与服务器集成说明

## 功能概览

Flutter应用现已完全集成服务器的身份验证功能，支持：

- 用户注册和登录
- 密码重置
- 游戏分数提交
- 排行榜查看
- 用户资料管理

## 主要修改文件

### 1. AuthService (`lib/services/auth_service.dart`)
- 更新API端点为本地服务器 `http://localhost:5000/api`
- 添加错误处理和用户友好的错误消息
- 集成JWT token管理
- 新增分数提交和排行榜功能

### 2. 新的排行榜页面 (`lib/widgets/ranking_new.dart`)
- 连接服务器API获取实时排行榜数据
- 显示用户名、分数、时间和难度
- 支持刷新和错误处理

### 3. 分数提交工具 (`lib/utils/score_helper.dart`)
- 提供分数计算算法
- 处理分数提交流程
- 用户友好的反馈界面

## 使用方法

### 启动服务器

1. 在项目根目录运行：
```bash
# Windows
start_server.bat

# 或手动启动
pip install -r requirements.txt
python server.py
```

2. 确保服务器运行在 `http://localhost:5000`

### 在游戏中使用

#### 提交分数示例

```dart
import '../utils/score_helper.dart';

// 游戏结束时调用
void onGameComplete() async {
  int finalScore = ScoreSubmissionHelper.calculateScore(
    timeInSeconds: gameTimeInSeconds,
    difficulty: 'medium', // 'easy', 'medium', 'hard'
    moves: totalMoves,
  );

  await ScoreSubmissionHelper.submitGameScore(
    context: context,
    score: finalScore,
    timeInSeconds: gameTimeInSeconds,
    difficulty: selectedDifficulty,
  );
}
```

#### 检查登录状态

```dart
import '../services/auth_service.dart';

final AuthService authService = AuthService();

void checkLoginStatus() {
  if (authService.isLoggedIn) {
    print('用户已登录: ${authService.currentUser?['username']}');
  } else {
    print('用户未登录');
  }
}
```

#### 获取排行榜

```dart
// 在排行榜页面中自动调用
// 或在其他地方手动获取
try {
  final leaderboard = await authService.getLeaderboard();
  print('排行榜数据: $leaderboard');
} catch (e) {
  print('获取排行榜失败: $e');
}
```

## API接口说明

### 认证相关

- `POST /api/auth/register` - 用户注册
  ```json
  {
    "username": "用户名",
    "email": "邮箱@example.com", 
    "password": "密码"
  }
  ```

- `POST /api/auth/login` - 用户登录
  ```json
  {
    "email": "邮箱@example.com",
    "password": "密码"
  }
  ```

- `POST /api/auth/reset-password` - 重置密码
  ```json
  {
    "email": "邮箱@example.com"
  }
  ```

### 分数相关

- `POST /api/scores` - 提交分数（需要登录）
  ```json
  {
    "score": 8500,
    "time": 180,
    "difficulty": "medium"
  }
  ```

- `GET /api/scores` - 获取排行榜（需要登录）

### 用户相关

- `GET /api/user/profile` - 获取用户资料（需要登录）

## 错误处理

所有API调用都包含完整的错误处理：

- 网络连接错误
- 服务器错误响应
- 用户未登录错误
- 数据验证错误

错误消息会显示给用户，并提供相应的解决方案。

## 注意事项

1. **服务器必须运行**：确保Python服务器在 `localhost:5000` 运行
2. **网络权限**：确保Flutter应用有网络访问权限
3. **CORS设置**：服务器已配置CORS允许跨域请求
4. **数据持久化**：当前使用内存存储，应用重启后需要重新登录

## 测试流程

1. 启动服务器
2. 运行Flutter应用
3. 注册新用户账号
4. 登录并查看用户状态
5. 完成游戏并提交分数
6. 查看排行榜验证数据

## 生产环境部署

在生产环境中：

1. 修改服务器URL为实际服务器地址
2. 使用真实数据库替代JSON文件存储
3. 配置HTTPS和安全认证
4. 实现真实的邮件重置功能