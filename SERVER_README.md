# 拼图游戏服务器

这是一个基于Flask的Python服务器，为拼图游戏提供用户认证和数据存储功能。

## 功能特性

- 用户注册和登录
- JWT令牌认证
- 密码重置
- 分数排行榜
- 用户资料管理
- 本地文件数据存储

## 快速开始

### 方法一：使用启动脚本（Windows）

1. 双击运行 `start_server.bat`
2. 脚本会自动安装依赖并启动服务器

### 方法二：手动启动

1. 确保已安装Python 3.7+

2. 安装依赖：
```bash
pip install -r requirements.txt
```

3. 启动服务器：
```bash
python server.py
```

## API接口文档

服务器启动后将运行在 `http://localhost:5000`

### 认证相关

- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录  
- `POST /api/auth/reset-password` - 重置密码
- `GET /api/auth/validate` - 验证token

### 分数相关

- `GET /api/scores` - 获取排行榜（需要登录）
- `POST /api/scores` - 提交分数（需要登录）

### 用户相关

- `GET /api/user/profile` - 获取用户资料（需要登录）

### 其他

- `GET /api/health` - 健康检查

## 数据存储

服务器使用本地JSON文件存储数据：

- `data/users.json` - 用户数据
- `data/scores.json` - 分数数据

## 请求示例

### 用户注册

```bash
curl -X POST http://localhost:5000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "123456"
  }'
```

### 用户登录

```bash
curl -X POST http://localhost:5000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "123456"
  }'
```

### 提交分数

```bash
curl -X POST http://localhost:5000/api/scores \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "score": 1000,
    "time": 180,
    "difficulty": "medium"
  }'
```

## 安全说明

- 密码使用SHA256哈希存储
- JWT令牌用于用户认证
- 支持CORS跨域请求
- 生产环境请修改SECRET_KEY

## 注意事项

1. 这是一个演示服务器，适合开发和测试
2. 生产环境建议使用数据库而非JSON文件
3. 请在生产环境中修改默认的SECRET_KEY
4. 确保防火墙允许5000端口访问