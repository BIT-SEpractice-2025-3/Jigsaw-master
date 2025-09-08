from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import hashlib
import datetime
import os
from functools import wraps
import jwt

app = Flask(__name__)
CORS(app)  # 允许跨域请求

# 配置
SECRET_KEY = 'your-secret-key-here'  # 在生产环境中应该使用更安全的密钥
DATA_DIR = 'data'
USERS_FILE = os.path.join(DATA_DIR, 'users.json')
SCORES_FILE = os.path.join(DATA_DIR, 'scores.json')

# 确保数据目录存在
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

# 初始化数据文件
def init_data_files():
    if not os.path.exists(USERS_FILE):
        with open(USERS_FILE, 'w', encoding='utf-8') as f:
            json.dump([], f, ensure_ascii=False, indent=2)
    
    if not os.path.exists(SCORES_FILE):
        # 创建一些示例分数数据
        sample_scores = [
            {
                'user_id': 1,
                'username': '示例玩家1',
                'score': 9500,
                'time': 180,
                'difficulty': 'hard',
                'created_at': datetime.datetime.now().isoformat()
            },
            {
                'user_id': 2,
                'username': '示例玩家2',
                'score': 8200,
                'time': 240,
                'difficulty': 'medium',
                'created_at': datetime.datetime.now().isoformat()
            },
            {
                'user_id': 3,
                'username': '示例玩家3',
                'score': 7100,
                'time': 160,
                'difficulty': 'easy',
                'created_at': datetime.datetime.now().isoformat()
            }
        ]
        with open(SCORES_FILE, 'w', encoding='utf-8') as f:
            json.dump(sample_scores, f, ensure_ascii=False, indent=2)

init_data_files()

# 辅助函数
def load_users():
    """加载用户数据"""
    try:
        with open(USERS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        return []

def save_users(users):
    """保存用户数据"""
    with open(USERS_FILE, 'w', encoding='utf-8') as f:
        json.dump(users, f, ensure_ascii=False, indent=2)

def load_scores():
    """加载分数数据"""
    try:
        with open(SCORES_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except:
        return []

def save_scores(scores):
    """保存分数数据"""
    with open(SCORES_FILE, 'w', encoding='utf-8') as f:
        json.dump(scores, f, ensure_ascii=False, indent=2)

def hash_password(password):
    """密码哈希"""
    return hashlib.sha256(password.encode()).hexdigest()

def generate_token(user_data):
    """生成JWT token"""
    if jwt is None:
        # 如果JWT不可用，返回简单的token
        import base64
        token_data = f"{user_data['id']}:{user_data['username']}:{user_data['email']}"
        return base64.b64encode(token_data.encode()).decode()
    
    payload = {
        'user_id': user_data['id'],
        'username': user_data['username'],
        'email': user_data['email'],
        'exp': datetime.datetime.utcnow() + datetime.timedelta(days=30)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def verify_token(token):
    """验证JWT token"""
    if jwt is None:
        # 简单token验证
        try:
            import base64
            token_data = base64.b64decode(token.encode()).decode()
            parts = token_data.split(':')
            if len(parts) == 3:
                return {
                    'user_id': int(parts[0]),
                    'username': parts[1],
                    'email': parts[2]
                }
        except:
            pass
        return None
    
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def token_required(f):
    """装饰器：需要token验证"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        if not token:
            return jsonify({'error': '缺少token'}), 401
        
        try:
            token = token.split(' ')[1]  # 移除 'Bearer ' 前缀
        except IndexError:
            return jsonify({'error': 'token格式错误'}), 401
        
        payload = verify_token(token)
        if not payload:
            return jsonify({'error': 'token无效或已过期'}), 401
        
        request.user = payload
        return f(*args, **kwargs)
    
    return decorated

# API路由

@app.route('/api/auth/register', methods=['POST'])
def register():
    """用户注册"""
    try:
        data = request.get_json()
        username = data.get('username', '').strip()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        # 验证输入
        if not username or not email or not password:
            return jsonify({'error': '用户名、邮箱和密码不能为空'}), 400
        
        if len(username) < 3:
            return jsonify({'error': '用户名至少3位'}), 400
        
        if len(password) < 6:
            return jsonify({'error': '密码至少6位'}), 400
        
        # 检查邮箱格式
        import re
        if not re.match(r'^[\w\.-]+@[\w\.-]+\.\w+$', email):
            return jsonify({'error': '邮箱格式不正确'}), 400
        
        users = load_users()
        
        # 检查用户是否已存在
        for user in users:
            if user['email'] == email:
                return jsonify({'error': '邮箱已被注册'}), 400
            if user['username'] == username:
                return jsonify({'error': '用户名已被使用'}), 400
        
        # 创建新用户
        new_user = {
            'id': len(users) + 1,
            'username': username,
            'email': email,
            'password': hash_password(password),
            'created_at': datetime.datetime.now().isoformat(),
            'best_score': 0,
            'games_played': 0
        }
        
        users.append(new_user)
        save_users(users)
        
        # 生成token
        user_data = {
            'id': new_user['id'],
            'username': new_user['username'],
            'email': new_user['email']
        }
        token = generate_token(user_data)
        
        return jsonify({
            'message': '注册成功',
            'token': token,
            'user': user_data
        }), 201
        
    except Exception as e:
        return jsonify({'error': f'注册失败: {str(e)}'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """用户登录"""
    try:
        data = request.get_json()
        email = data.get('email', '').strip().lower()
        password = data.get('password', '')
        
        if not email or not password:
            return jsonify({'error': '邮箱和密码不能为空'}), 400
        
        users = load_users()
        
        # 查找用户
        user = None
        for u in users:
            if u['email'] == email:
                user = u
                break
        
        if not user or user['password'] != hash_password(password):
            return jsonify({'error': '邮箱或密码错误'}), 401
        
        # 生成token
        user_data = {
            'id': user['id'],
            'username': user['username'],
            'email': user['email']
        }
        token = generate_token(user_data)
        
        return jsonify({
            'message': '登录成功',
            'token': token,
            'user': user_data
        }), 200
        
    except Exception as e:
        return jsonify({'error': f'登录失败: {str(e)}'}), 500

@app.route('/api/auth/reset-password', methods=['POST'])
def reset_password():
    """重置密码"""
    try:
        data = request.get_json()
        email = data.get('email', '').strip().lower()
        
        if not email:
            return jsonify({'error': '邮箱不能为空'}), 400
        
        users = load_users()
        
        # 检查用户是否存在
        user_exists = any(user['email'] == email for user in users)
        
        if not user_exists:
            return jsonify({'error': '邮箱不存在'}), 404
        
        # 在实际应用中，这里应该发送重置密码邮件
        # 现在只是返回成功消息
        return jsonify({'message': '重置密码邮件已发送'}), 200
        
    except Exception as e:
        return jsonify({'error': f'重置密码失败: {str(e)}'}), 500

@app.route('/api/auth/validate', methods=['GET'])
@token_required
def validate_token():
    """验证token有效性"""
    return jsonify({
        'valid': True,
        'user': {
            'id': request.user['user_id'],
            'username': request.user['username'],
            'email': request.user['email']
        }
    }), 200

@app.route('/api/scores', methods=['GET'])
@token_required
def get_scores():
    """获取排行榜"""
    try:
        scores = load_scores()
        # 按分数降序排序
        scores.sort(key=lambda x: x['score'], reverse=True)
        return jsonify(scores[:50]), 200  # 返回前50名
    except Exception as e:
        return jsonify({'error': f'获取排行榜失败: {str(e)}'}), 500

@app.route('/api/scores', methods=['POST'])
@token_required
def submit_score():
    """提交分数"""
    try:
        data = request.get_json()
        score = data.get('score', 0)
        time = data.get('time', 0)
        difficulty = data.get('difficulty', 'easy')
        
        if score < 0:
            return jsonify({'error': '分数不能为负数'}), 400
        
        scores = load_scores()
        users = load_users()
        
        # 添加新分数记录
        new_score = {
            'user_id': request.user['user_id'],
            'username': request.user['username'],
            'score': score,
            'time': time,
            'difficulty': difficulty,
            'created_at': datetime.datetime.now().isoformat()
        }
        
        scores.append(new_score)
        save_scores(scores)
        
        # 更新用户最佳分数
        for user in users:
            if user['id'] == request.user['user_id']:
                user['games_played'] += 1
                if score > user['best_score']:
                    user['best_score'] = score
                break
        
        save_users(users)
        
        return jsonify({'message': '分数提交成功'}), 201
        
    except Exception as e:
        return jsonify({'error': f'提交分数失败: {str(e)}'}), 500

@app.route('/api/user/profile', methods=['GET'])
@token_required
def get_profile():
    """获取用户资料"""
    try:
        users = load_users()
        user = None
        
        for u in users:
            if u['id'] == request.user['user_id']:
                user = u
                break
        
        if not user:
            return jsonify({'error': '用户不存在'}), 404
        
        # 获取用户分数历史
        scores = load_scores()
        user_scores = [s for s in scores if s['user_id'] == user['id']]
        
        profile = {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'best_score': user['best_score'],
            'games_played': user['games_played'],
            'created_at': user['created_at'],
            'recent_scores': sorted(user_scores, key=lambda x: x['created_at'], reverse=True)[:10]
        }
        
        return jsonify(profile), 200
        
    except Exception as e:
        return jsonify({'error': f'获取用户资料失败: {str(e)}'}), 500

# 健康检查
@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat()
    }), 200

# 错误处理
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': '接口不存在'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': '服务器内部错误'}), 500

if __name__ == '__main__':
    print("拼图游戏服务器启动中...")
    print("API文档:")
    print("POST /api/auth/register - 用户注册")
    print("POST /api/auth/login - 用户登录")
    print("POST /api/auth/reset-password - 重置密码")
    print("GET  /api/auth/validate - 验证token")
    print("GET  /api/scores - 获取排行榜")
    print("POST /api/scores - 提交分数")
    print("GET  /api/user/profile - 获取用户资料")
    print("\n服务器运行在: http://localhost:5000")
    
    app.run(debug=True, host='0.0.0.0', port=5000)