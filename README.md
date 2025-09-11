# 拼图游戏项目 - AI增强测试框架

## 项目概述

这是一个集成了AI技术的智能测试框架，用于测试拼图游戏应用。该框架结合了传统测试方法和AI技术，提供全面的测试覆盖和智能化的测试管理。

## 项目结构

```
jigsaw/
├── lib/                          # Flutter源代码
│   ├── config/
│   ├── models/
│   ├── services/
│   ├── utils/
│   └── widgets/
├── test/                         # Flutter测试文件
│   ├── *_test.dart
│   └── integration_test/
├── server/                       # Python后端代码
├── scripts/                      # AI测试脚本
│   ├── ai_test_generator.py      # AI测试用例生成器
│   ├── defect_analyzer.py        # 缺陷分析器
│   ├── quality_predictor.py      # 质量预测器
│   └── test_runner.py           # 测试运行器
├── TEST_DOCUMENTATION.md         # 详细测试文档
└── README.md                     # 项目说明
```

## 快速开始

### 1. 环境设置

```bash
# 克隆项目
git clone <repository-url>
cd jigsaw

# 安装Flutter依赖
flutter pub get

# 安装Python依赖
pip install -r requirements.txt

# 安装AI相关依赖
pip install openai pandas scikit-learn tensorflow torch
```

### 2. 运行测试

```bash
# 运行所有Flutter测试
flutter test

# 运行Python测试
cd server && python -m pytest

# 运行AI脚本演示
python scripts/ai_test_generator.py
python scripts/defect_analyzer.py
python scripts/quality_predictor.py

# 批量运行所有测试
python scripts/test_runner.py
```

## AI增强功能

### 🤖 智能测试用例生成
- 基于需求文档自动生成测试用例
- 生成边界测试用例和异常情况测试
- 智能测试数据生成

### 📊 缺陷智能分析
- 自动分类缺陷类型
- 识别缺陷模式和根本原因
- 预测缺陷趋势

### ⚡ 自适应测试执行
- 根据代码变更动态调整测试策略
- 智能测试优先级排序
- 优化测试执行顺序

### 📈 预测性质量分析
- 预测代码中的潜在缺陷
- 质量趋势分析
- 智能改进建议

## 测试覆盖

### 单元测试
- 服务层测试 (AuthService, PuzzleGameService, etc.)
- 模型层测试 (User, Match, PuzzlePiece, etc.)
- 工具类测试 (ScoreHelper, etc.)
- 配置类测试 (AppConfig)

### 集成测试
- API端点测试
- 数据库操作测试
- Socket.IO通信测试

### 端到端测试
- 用户注册和登录流程
- 游戏创建和加入流程
- 拼图游戏完整流程

## AI脚本使用

### 测试用例生成器
```bash
# 生成认证相关测试
python scripts/ai_test_generator.py
```

### 缺陷分析器
```bash
# 运行缺陷分析演示
python scripts/defect_analyzer.py
```

### 质量预测器
```bash
# 运行质量预测演示
python scripts/quality_predictor.py
```

## 文档

详细的测试文档请参考 [TEST_DOCUMENTATION.md](TEST_DOCUMENTATION.md)，其中包含：

- 完整的测试策略和方法
- 详细的测试用例说明
- 测试执行指南
- AI增强功能的实现细节
- 常见问题解答

## 贡献

欢迎提交问题和改进建议！

## 许可证

本项目采用 MIT 许可证。
