#!/usr/bin/env python3
"""
AI缺陷分析器脚本
用于演示如何使用AI分析缺陷模式
"""

import json
import re
from collections import Counter, defaultdict
from typing import Dict, List

class SimpleAIDefectAnalyzer:
    """简单的AI缺陷分析器示例"""

    def __init__(self):
        self.defect_patterns = {
            'auth': ['login', 'register', 'token', 'password', 'email'],
            'network': ['connection', 'timeout', 'socket', 'api', 'server'],
            'ui': ['display', 'render', 'layout', 'button', 'text'],
            'data': ['database', 'query', 'save', 'load', 'validation'],
            'performance': ['slow', 'memory', 'cpu', 'lag', 'freeze']
        }

    def analyze_defect(self, description: str) -> Dict:
        """分析单个缺陷"""
        description_lower = description.lower()

        # 分类缺陷
        category = self._classify_defect(description_lower)

        # 提取关键词
        keywords = self._extract_keywords(description_lower)

        # 评估严重程度
        severity = self._assess_severity(description_lower)

        # 建议修复方案
        suggestions = self._generate_suggestions(category, keywords)

        return {
            'description': description,
            'category': category,
            'keywords': keywords,
            'severity': severity,
            'suggestions': suggestions
        }

    def _classify_defect(self, description: str) -> str:
        """分类缺陷"""
        max_matches = 0
        best_category = 'unknown'

        for category, patterns in self.defect_patterns.items():
            matches = sum(1 for pattern in patterns if pattern in description)
            if matches > max_matches:
                max_matches = matches
                best_category = category

        return best_category

    def _extract_keywords(self, description: str) -> List[str]:
        """提取关键词"""
        words = re.findall(r'\b\w+\b', description)
        # 过滤常见停用词
        stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'}
        keywords = [word for word in words if len(word) > 2 and word not in stop_words]

        # 返回最常见的关键词
        return [word for word, _ in Counter(keywords).most_common(5)]

    def _assess_severity(self, description: str) -> str:
        """评估严重程度"""
        high_severity_keywords = ['crash', 'error', 'fail', 'broken', 'cannot', 'unable']
        medium_severity_keywords = ['slow', 'wrong', 'missing', 'incorrect', 'bug']

        if any(keyword in description for keyword in high_severity_keywords):
            return 'high'
        elif any(keyword in description for keyword in medium_severity_keywords):
            return 'medium'
        else:
            return 'low'

    def _generate_suggestions(self, category: str, keywords: List[str]) -> List[str]:
        """生成修复建议"""
        suggestions = []

        if category == 'auth':
            suggestions.extend([
                '检查认证逻辑和token验证',
                '验证用户输入数据的格式',
                '测试边界情况和异常处理'
            ])
        elif category == 'network':
            suggestions.extend([
                '检查网络连接和超时处理',
                '验证API端点和响应格式',
                '测试网络异常情况'
            ])
        elif category == 'ui':
            suggestions.extend([
                '检查UI组件的渲染逻辑',
                '验证布局和样式设置',
                '测试不同屏幕尺寸的适配'
            ])
        elif category == 'data':
            suggestions.extend([
                '检查数据库查询和数据验证',
                '验证数据保存和加载逻辑',
                '测试数据一致性'
            ])
        elif category == 'performance':
            suggestions.extend([
                '分析性能瓶颈和资源使用',
                '优化算法和数据结构',
                '检查内存泄漏和资源释放'
            ])

        return suggestions

    def analyze_defect_patterns(self, defects: List[Dict]) -> Dict:
        """分析缺陷模式"""
        pattern_analysis = defaultdict(int)
        category_counts = defaultdict(int)
        severity_counts = defaultdict(int)

        for defect in defects:
            if isinstance(defect, dict) and 'description' in defect:
                analysis = self.analyze_defect(defect['description'])
                pattern_analysis[analysis['category']] += 1
                category_counts[analysis['category']] += 1
                severity_counts[analysis['severity']] += 1

        return {
            'total_defects': len(defects),
            'category_distribution': dict(category_counts),
            'severity_distribution': dict(severity_counts),
            'patterns': dict(pattern_analysis)
        }

def main():
    """主函数"""
    analyzer = SimpleAIDefectAnalyzer()

    # 示例缺陷数据
    sample_defects = [
        {'description': 'Login button crashes when clicked with empty email'},
        {'description': 'Network timeout when loading user profile'},
        {'description': 'UI layout breaks on small screens'},
        {'description': 'Cannot save game progress to database'},
        {'description': 'App becomes slow after playing for 30 minutes'},
        {'description': 'Password reset email not received'},
        {'description': 'Game pieces disappear during gameplay'}
    ]

    print("=== AI 缺陷分析报告 ===\n")

    # 分析每个缺陷
    for i, defect in enumerate(sample_defects, 1):
        analysis = analyzer.analyze_defect(defect['description'])
        print(f"缺陷 {i}: {defect['description']}")
        print(f"  类别: {analysis['category']}")
        print(f"  严重程度: {analysis['severity']}")
        print(f"  关键词: {', '.join(analysis['keywords'])}")
        print("  修复建议:")
        for suggestion in analysis['suggestions']:
            print(f"    - {suggestion}")
        print()

    # 分析整体模式
    pattern_analysis = analyzer.analyze_defect_patterns(sample_defects)
    print("=== 缺陷模式分析 ===")
    print(f"总缺陷数: {pattern_analysis['total_defects']}")
    print(f"类别分布: {pattern_analysis['category_distribution']}")
    print(f"严重程度分布: {pattern_analysis['severity_distribution']}")

if __name__ == '__main__':
    main()