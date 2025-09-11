#!/usr/bin/env python3
"""
AI质量预测器脚本
用于演示如何预测代码质量和潜在缺陷
"""

import json
import statistics
from typing import Dict, List

class SimpleQualityPredictor:
    """简单的质量预测器示例"""

    def __init__(self):
        self.quality_thresholds = {
            'lines_of_code': {'good': 300, 'warning': 500},
            'cyclomatic_complexity': {'good': 10, 'warning': 20},
            'test_coverage': {'good': 80, 'warning': 60},
            'code_duplication': {'good': 5, 'warning': 15}
        }

    def predict_quality(self, metrics: Dict) -> Dict:
        """预测代码质量"""
        issues = []
        risk_level = 'low'
        score = 100

        # 分析代码行数
        loc = metrics.get('lines_of_code', 0)
        if loc > self.quality_thresholds['lines_of_code']['warning']:
            issues.append(f"代码行数过高 ({loc} 行)，建议拆分")
            score -= 20
            risk_level = 'high'
        elif loc > self.quality_thresholds['lines_of_code']['good']:
            issues.append(f"代码行数较高 ({loc} 行)")
            score -= 10
            if risk_level == 'low':
                risk_level = 'medium'

        # 分析圈复杂度
        complexity = metrics.get('cyclomatic_complexity', 0)
        if complexity > self.quality_thresholds['cyclomatic_complexity']['warning']:
            issues.append(f"圈复杂度过高 ({complexity})，建议重构")
            score -= 25
            risk_level = 'high'
        elif complexity > self.quality_thresholds['cyclomatic_complexity']['good']:
            issues.append(f"圈复杂度较高 ({complexity})")
            score -= 15
            if risk_level == 'low':
                risk_level = 'medium'

        # 分析测试覆盖率
        coverage = metrics.get('test_coverage', 0)
        if coverage < self.quality_thresholds['test_coverage']['warning']:
            issues.append(f"测试覆盖率过低 ({coverage}%)，建议增加测试")
            score -= 30
            risk_level = 'high'
        elif coverage < self.quality_thresholds['test_coverage']['good']:
            issues.append(f"测试覆盖率较低 ({coverage}%)")
            score -= 15
            if risk_level == 'low':
                risk_level = 'medium'

        # 分析代码重复
        duplication = metrics.get('code_duplication', 0)
        if duplication > self.quality_thresholds['code_duplication']['warning']:
            issues.append(f"代码重复率过高 ({duplication}%)，建议重构")
            score -= 20
            risk_level = 'high'
        elif duplication > self.quality_thresholds['code_duplication']['good']:
            issues.append(f"代码重复率较高 ({duplication}%)")
            score -= 10
            if risk_level == 'low':
                risk_level = 'medium'

        # 生成建议
        recommendations = self._generate_recommendations(issues, metrics)

        return {
            'overall_score': max(0, score),
            'risk_level': risk_level,
            'issues': issues,
            'recommendations': recommendations,
            'metrics': metrics
        }

    def _generate_recommendations(self, issues: List[str], metrics: Dict) -> List[str]:
        """生成改进建议"""
        recommendations = []

        if any('行数' in issue for issue in issues):
            recommendations.extend([
                '将大函数拆分为多个小函数',
                '提取重复代码到公共方法中',
                '考虑将类拆分为多个更小的类'
            ])

        if any('复杂度' in issue for issue in issues):
            recommendations.extend([
                '重构复杂条件语句',
                '提取方法减少嵌套深度',
                '使用策略模式替换复杂条件判断'
            ])

        if any('覆盖率' in issue for issue in issues):
            recommendations.extend([
                '为未测试的代码路径添加单元测试',
                '编写集成测试覆盖主要功能',
                '使用测试覆盖率工具识别未覆盖代码'
            ])

        if any('重复' in issue for issue in issues):
            recommendations.extend([
                '提取公共代码到工具类中',
                '使用继承或组合减少重复',
                '应用DRY原则重构代码'
            ])

        if not recommendations:
            recommendations.append('代码质量良好，继续保持')

        return recommendations

    def predict_trend(self, historical_metrics: List[Dict]) -> Dict:
        """预测质量趋势"""
        if len(historical_metrics) < 2:
            return {'trend': 'insufficient_data'}

        scores = []
        for metrics in historical_metrics:
            prediction = self.predict_quality(metrics)
            scores.append(prediction['overall_score'])

        # 计算趋势
        if len(scores) >= 2:
            recent_avg = statistics.mean(scores[-3:]) if len(scores) >= 3 else statistics.mean(scores[-2:])
            older_avg = statistics.mean(scores[:-3]) if len(scores) >= 3 else scores[0]

            if recent_avg > older_avg + 5:
                trend = 'improving'
            elif recent_avg < older_avg - 5:
                trend = 'declining'
            else:
                trend = 'stable'
        else:
            trend = 'stable'

        return {
            'trend': trend,
            'current_score': scores[-1] if scores else 0,
            'average_score': statistics.mean(scores) if scores else 0,
            'score_history': scores
        }

def main():
    """主函数"""
    predictor = SimpleQualityPredictor()

    # 示例代码度量数据
    sample_metrics = [
        {
            'file': 'lib/services/auth_service.dart',
            'lines_of_code': 450,
            'cyclomatic_complexity': 25,
            'test_coverage': 65,
            'code_duplication': 8
        },
        {
            'file': 'lib/services/puzzle_game_service.dart',
            'lines_of_code': 320,
            'cyclomatic_complexity': 15,
            'test_coverage': 85,
            'code_duplication': 3
        },
        {
            'file': 'lib/widgets/home.dart',
            'lines_of_code': 180,
            'cyclomatic_complexity': 8,
            'test_coverage': 90,
            'code_duplication': 2
        }
    ]

    print("=== AI 质量预测报告 ===\n")

    # 分析每个文件的质量
    for metrics in sample_metrics:
        prediction = predictor.predict_quality(metrics)
        print(f"文件: {metrics['file']}")
        print(f"  质量评分: {prediction['overall_score']}/100")
        print(f"  风险等级: {prediction['risk_level']}")
        print("  发现问题:")
        for issue in prediction['issues']:
            print(f"    - {issue}")
        print("  改进建议:")
        for rec in prediction['recommendations']:
            print(f"    - {rec}")
        print()

    # 分析整体趋势
    trend_analysis = predictor.predict_trend(sample_metrics)
    print("=== 质量趋势分析 ===")
    print(f"当前平均评分: {trend_analysis['average_score']:.1f}/100")
    print(f"质量趋势: {trend_analysis['trend']}")
    print(f"评分历史: {trend_analysis['score_history']}")

if __name__ == '__main__':
    main()