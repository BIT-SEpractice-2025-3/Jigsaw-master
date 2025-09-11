#!/usr/bin/env python3
"""
测试运行器脚本
用于批量运行和报告测试结果
"""

import subprocess
import sys
import os
from datetime import datetime
from typing import Dict

class TestRunner:
    """测试运行器"""

    def __init__(self, project_root: str):
        self.project_root = project_root
        self.test_results = {}

    def run_flutter_tests(self) -> Dict:
        """运行Flutter测试"""
        print("Running Flutter tests...")

        try:
            # 切换到项目根目录
            os.chdir(self.project_root)

            # 运行Flutter测试
            result = subprocess.run(
                ['flutter', 'test', '--coverage'],
                capture_output=True,
                text=True,
                timeout=300
            )

            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr,
                'return_code': result.returncode
            }

        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'output': '',
                'error': 'Test execution timed out',
                'return_code': -1
            }
        except FileNotFoundError:
            return {
                'success': False,
                'output': '',
                'error': 'Flutter command not found',
                'return_code': -1
            }

    def run_python_tests(self) -> Dict:
        """运行Python测试"""
        print("Running Python tests...")

        try:
            # 切换到服务器目录
            server_dir = os.path.join(self.project_root, 'server')
            if os.path.exists(server_dir):
                os.chdir(server_dir)
            else:
                os.chdir(self.project_root)

            # 运行Python测试
            result = subprocess.run(
                ['python', '-m', 'pytest', '--tb=short'],
                capture_output=True,
                text=True,
                timeout=180
            )

            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr,
                'return_code': result.returncode
            }

        except subprocess.TimeoutExpired:
            return {
                'success': False,
                'output': '',
                'error': 'Python test execution timed out',
                'return_code': -1
            }

    def run_ai_scripts(self) -> Dict:
        """运行AI脚本演示"""
        print("Running AI scripts...")

        results = {}
        scripts_dir = os.path.join(self.project_root, 'scripts')

        if not os.path.exists(scripts_dir):
            return {'error': 'Scripts directory not found'}

        ai_scripts = [
            'ai_test_generator.py',
            'defect_analyzer.py',
            'quality_predictor.py'
        ]

        for script in ai_scripts:
            script_path = os.path.join(scripts_dir, script)
            if os.path.exists(script_path):
                try:
                    result = subprocess.run(
                        ['python', script_path],
                        capture_output=True,
                        text=True,
                        timeout=60
                    )

                    results[script] = {
                        'success': result.returncode == 0,
                        'output': result.stdout,
                        'error': result.stderr
                    }

                except subprocess.TimeoutExpired:
                    results[script] = {
                        'success': False,
                        'output': '',
                        'error': 'Script execution timed out'
                    }
            else:
                results[script] = {
                    'success': False,
                    'output': '',
                    'error': f'Script not found: {script_path}'
                }

        return results

    def generate_report(self) -> str:
        """生成测试报告"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        report = f"""
# 测试执行报告
生成时间: {timestamp}

## 测试结果汇总

"""

        # Flutter测试结果
        if 'flutter' in self.test_results:
            flutter_result = self.test_results['flutter']
            status = "✅ 通过" if flutter_result['success'] else "❌ 失败"
            report += f"### Flutter 测试: {status}\n\n"

            if flutter_result['error']:
                report += f"错误信息:\n{flutter_result['error']}\n\n"

        # Python测试结果
        if 'python' in self.test_results:
            python_result = self.test_results['python']
            status = "✅ 通过" if python_result['success'] else "❌ 失败"
            report += f"### Python 测试: {status}\n\n"

            if python_result['error']:
                report += f"错误信息:\n{python_result['error']}\n\n"

        # AI脚本结果
        if 'ai_scripts' in self.test_results:
            report += "### AI 脚本演示\n\n"
            ai_results = self.test_results['ai_scripts']

            for script, result in ai_results.items():
                status = "✅ 成功" if result['success'] else "❌ 失败"
                report += f"#### {script}: {status}\n\n"

                if result['error'] and 'not found' not in result['error']:
                    report += f"错误信息:\n{result['error']}\n\n"

        return report

    def run_all_tests(self) -> Dict:
        """运行所有测试"""
        print("=== 开始测试执行 ===\n")

        # 运行Flutter测试
        self.test_results['flutter'] = self.run_flutter_tests()

        # 运行Python测试
        self.test_results['python'] = self.run_python_tests()

        # 运行AI脚本
        self.test_results['ai_scripts'] = self.run_ai_scripts()

        print("\n=== 测试执行完成 ===")

        return self.test_results

def main():
    """主函数"""
    if len(sys.argv) > 1:
        project_root = sys.argv[1]
    else:
        project_root = os.getcwd()

    runner = TestRunner(project_root)
    results = runner.run_all_tests()

    # 生成并打印报告
    report = runner.generate_report()
    print(report)

    # 保存报告到文件
    report_file = os.path.join(project_root, 'test_report.md')
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(report)

    print(f"详细报告已保存到: {report_file}")

    # 返回适当的退出码
    flutter_success = results.get('flutter', {}).get('success', False)
    python_success = results.get('python', {}).get('success', False)

    if flutter_success and python_success:
        sys.exit(0)
    else:
        sys.exit(1)

if __name__ == '__main__':
    main()