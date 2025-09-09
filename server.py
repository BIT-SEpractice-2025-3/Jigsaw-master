from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import time
import hashlib
import datetime
from decimal import Decimal
from functools import wraps
import jwt
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)
CORS(app)  # 允许跨域请求

# 配置
SECRET_KEY = 'your-secret-key-here'  # 在生产环境中应该使用更安全的密钥

# 数据库配置
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',
    'password': '123dsk',
    'database': 'jigsaw',
    'charset': 'utf8mb4'
}

# 数据库连接函数
def get_db_connection():
    """获取数据库连接"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"数据库连接失败: {e}")
        return None

def execute_query(query, params=None, fetch=False):
    """执行数据库查询"""
    connection = get_db_connection()
    if not connection:
        return None

    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query, params or ())

        if fetch:
            result = cursor.fetchall() if fetch == 'all' else cursor.fetchone()
        else:
            connection.commit()
            result = cursor.lastrowid

        return result
    except Error as e:
        print(f"查询执行失败: {e}")
        if connection:
            connection.rollback()
        return None
    finally:
        if connection and connection.is_connected():
            cursor.close()
            connection.close()

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
        if not re.match(r'^[\w.-]+@[\w.-]+\.\w+$', email):
            return jsonify({'error': '邮箱格式不正确'}), 400

        # 检查用户名是否已存在
        existing_user = execute_query(
            "SELECT id FROM users WHERE username = %s OR email = %s",
            (username, email),
            fetch='one'
        )
        if existing_user:
            return jsonify({'error': '用户名或邮箱已存在'}), 409

        # 创建新用户
        password_hash = hash_password(password)
        user_id = execute_query(
            "INSERT INTO users (username, email, password_hash) VALUES (%s, %s, %s)",
            (username, email, password_hash)
        )

        if user_id:
            # 生成token
            user_data = {
                'id': user_id,
                'username': username,
                'email': email
            }
            token = generate_token(user_data)

            return jsonify({
                'message': '注册成功',
                'token': token,
                'user': user_data
            }), 201
        else:
            return jsonify({'error': '注册失败'}), 500

    except Exception as e:
        return jsonify({'error': f'注册失败: {str(e)}'}), 500

@app.route('/api/auth/login', methods=['POST'])
def login():
    """用户登录"""
    try:
        data = request.get_json()
        email = data.get('email', '').strip()
        password = data.get('password', '')
        
        if not email or not password:
            return jsonify({'error': '邮箱和密码不能为空'}), 400

        # 查找用户（支持用户名或邮箱登录）
        user = execute_query(
            "SELECT id, username, email, password_hash FROM users WHERE username = %s OR email = %s",
            (email, email.lower()),
            fetch='one'
        )

        if not user:
            return jsonify({'error': '用户不存在'}), 404

        # 验证密码
        if user['password_hash'] != hash_password(password):
            return jsonify({'error': '密码错误'}), 401

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
        
        # 检查用户是否存在
        user = execute_query(
            "SELECT id FROM users WHERE email = %s",
            (email,),
            fetch='one'
        )

        if not user:
            return jsonify({'error': '邮箱不存在'}), 404
        
        # 在实际应用中，这里应该发送重置密码邮件
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
def get_leaderboard():
    """获取分数排行榜"""
    try:
        difficulty = request.args.get('difficulty', 'all')
        limit = int(request.args.get('limit', 10))

        query = """
        SELECT s.id, s.score, s.difficulty, s.time_taken as time, s.created_at,
               u.username
        FROM scores s
        JOIN users u ON s.user_id = u.id
        """
        params = []

        if difficulty != 'all':
            query += " WHERE s.difficulty = %s"
            params.append(difficulty)

        query += " ORDER BY s.score DESC, s.time_taken ASC LIMIT %s"
        params.append(limit)

        scores = execute_query(query, params, fetch='all')

        # 直接返回分数数组，与前端期望格式匹配
        return jsonify(scores or []), 200

    except Exception as e:
        return jsonify({'error': f'获取分数失败: {str(e)}'}), 500

@app.route('/api/scores', methods=['POST'])
@token_required
def submit_score():
    """提交分数"""
    try:
        data = request.get_json()
        score = data.get('score')
        difficulty = data.get('difficulty', 'easy')
        # 支持前端发送的 'time' 字段，同时兼容 'time_taken'
        time_taken = data.get('time') or data.get('time_taken')

        if score is None or time_taken is None:
            return jsonify({'error': '分数和时间不能为空'}), 400

        if not isinstance(score, int) or score < 0:
            return jsonify({'error': '分数必须是非负整数'}), 400

        if not isinstance(time_taken, int) or time_taken < 0:
            return jsonify({'error': '时间必须是非负整数'}), 400

        if difficulty not in ['easy', 'medium', 'hard', 'master']:
            return jsonify({'error': '难度必须是 easy, medium, master 或 hard'}), 400

        # 插入分数记录
        score_id = execute_query(
            "INSERT INTO scores (user_id, score, difficulty, time_taken) VALUES (%s, %s, %s, %s)",
            (request.user['user_id'], score, difficulty, time_taken)
        )

        if score_id:
            user_id = request.user['user_id']
            # 删除 game_saves 记录
            execute_query(
                "DELETE FROM game_saves WHERE user_id = %s AND difficulty = %s",
                (user_id, str(difficulty))
            )
            return jsonify({
                'message': '分数提交成功',
                'score_id': score_id
            }), 201
        else:
            return jsonify({'error': '分数提交失败'}), 500

    except Exception as e:
        return jsonify({'error': f'提交分数失败: {str(e)}'}), 500

@app.route('/api/user/profile', methods=['GET'])
@token_required
def get_profile():
    """获取用户资料"""
    try:
        user_id = request.user['user_id']

        # 获取用户基本信息
        user = execute_query(
            "SELECT id, username, email, created_at FROM users WHERE id = %s",
            (user_id,),
            fetch='one'
        )

        if not user:
            return jsonify({'error': '用户不存在'}), 404
        
        # 获取用户统计信息
        stats = execute_query(
            """
            SELECT 
                COUNT(*) as games_played,
                IFNULL(MAX(score), 0) as best_score,
                IFNULL(AVG(score), 0) as avg_score,
                IFNULL(MIN(time_taken), 0) as best_time
            FROM scores 
            WHERE user_id = %s
            """,
            (user_id,),
            fetch='one'
        )

        return jsonify({
            'user': user,
            'stats': stats or {
                'games_played': 0,
                'best_score': 0,
                'avg_score': 0,
                'best_time': 0
            }
        }), 200

    except Exception as e:
        return jsonify({'error': f'获取用户资料失败: {str(e)}'}), 500

@app.route('/api/save-game', methods=['POST'])
@token_required
def submit_save():
    """保存游戏进度"""
    try:
        data = request.get_json()

        # 从前端数据中提取字段
        game_mode = data.get('gameMode', 'classic')
        difficulty = str(data.get('difficulty', 1))  # 将 int 转换为 str
        elapsed_seconds = data.get('elapsedSeconds', 0)
        current_score = data.get('currentScore', 0)
        image_source = data.get('imageSource', 'assets/images/default_puzzle.jpg')
        placed_pieces_ids = data.get('placedPiecesIds', [])
        available_pieces_ids = data.get('availablePiecesIds', [])
        
        # 新增：支持大师模式的拼图块数据
        master_pieces = data.get('masterPieces', [])

        # 生成存档名称（如果前端没有提供）
        save_name = data.get('save_name', f"auto_save_{int(time.time())}")

        # 计算游戏进度（可选，基于已放置的拼图块数量）
        if game_mode == 'master':
            # 大师模式：基于拼图块组数计算进度
            total_pieces = len(master_pieces)
            if total_pieces > 0:
                # 简单地基于拼图块数量计算进度，实际可以根据需要调整
                progress = min(100.0, (total_pieces / (data.get('difficulty', 1) * data.get('difficulty', 1) * 9)) * 100)
            else:
                progress = 0.0
        else:
            # 经典模式：基于已放置的拼图块数量
            total_pieces = len(placed_pieces_ids) + len(available_pieces_ids)
            placed_count = len([p for p in placed_pieces_ids if p is not None])
            progress = (placed_count / total_pieces * 100) if total_pieces > 0 else 0.0

        if not game_mode:
            return jsonify({'error': '游戏模式不能为空'}), 400

        user_id = request.user['user_id']

        # 检查是否已存在相同 gameMode 和 difficulty 的存档
        existing_save = execute_query(
            "SELECT id FROM game_saves WHERE user_id = %s AND game_mode = %s AND difficulty = %s",
            (user_id, game_mode, difficulty),
            fetch='one'
        )

        if existing_save:
            # 更新现有存档
            result = execute_query(
                """
                UPDATE game_saves 
                SET elapsed_seconds = %s, current_score = %s, image_source = %s, 
                    placed_pieces_ids = %s, available_pieces_ids = %s, master_pieces = %s,
                    progress = %s, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = %s AND game_mode = %s AND difficulty = %s
                """,
                (elapsed_seconds, current_score, image_source,
                 json.dumps(placed_pieces_ids), json.dumps(available_pieces_ids), 
                 json.dumps(master_pieces), progress,
                 user_id, game_mode, difficulty)
            )
            save_id = existing_save['id']
        else:
            # 创建新存档
            save_id = execute_query(
                """
                INSERT INTO game_saves (user_id, save_name, game_mode, difficulty, elapsed_seconds, 
                                      current_score, image_source, placed_pieces_ids, available_pieces_ids, 
                                      master_pieces, progress) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (user_id, save_name, game_mode, difficulty, elapsed_seconds, current_score,
                 image_source, json.dumps(placed_pieces_ids), json.dumps(available_pieces_ids),
                 json.dumps(master_pieces), progress)
            )

        if save_id:
            return jsonify({
                'message': '游戏保存成功',
                'save_id': save_id,
                'save_name': save_name,
                'progress': progress
            }), 201
        else:
            return jsonify({'error': '游戏保存失败'}), 500

    except Exception as e:
        return jsonify({'error': f'保存游戏失败: {str(e)}'}), 500

@app.route('/api/load-save', methods=['GET'])
@token_required
def load_save():
    """加载游戏存档"""
    try:
        user_id = request.user['user_id']
        game_mode = request.args.get('gameMode', '').strip()
        difficulty = request.args.get('difficulty', '').strip()
        save_name = request.args.get('save_name', '').strip()

        # 如果 difficulty 是数字字符串，保持原样
        if difficulty:
            difficulty = str(difficulty)

        # 如果没有指定任何参数，返回用户所有存档列表
        if not game_mode and not difficulty and not save_name:
            saves = execute_query(
                """
                SELECT id, save_name, game_mode, difficulty, elapsed_seconds, current_score,
                       image_source, progress, created_at, updated_at 
                FROM game_saves 
                WHERE user_id = %s 
                ORDER BY updated_at DESC
                """,
                (user_id,),
                fetch='all'
            )
            return jsonify({'saves': saves or []}), 200

        # 构建查询条件
        query_conditions = ["user_id = %s"]
        query_params = [user_id]

        if game_mode:
            query_conditions.append("game_mode = %s")
            query_params.append(game_mode)

        if difficulty:
            query_conditions.append("difficulty = %s")
            query_params.append(difficulty)

        if save_name:
            query_conditions.append("save_name = %s")
            query_params.append(save_name)

        # 查询匹配条件的最新存档
        save_data = execute_query(
            f"""
            SELECT id, save_name, game_mode, difficulty, elapsed_seconds, current_score,
                   image_source, placed_pieces_ids, available_pieces_ids, master_pieces, progress, 
                   created_at, updated_at 
            FROM game_saves 
            WHERE {' AND '.join(query_conditions)}
            ORDER BY updated_at DESC
            LIMIT 1
            """,
            query_params,
            fetch='one'
        )

        if not save_data:
            return jsonify({'error': '存档不存在'}), 404
        
        # 解析JSON数据
        try:
            if save_data['placed_pieces_ids']:
                save_data['placedPiecesIds'] = json.loads(save_data['placed_pieces_ids'])
            else:
                save_data['placedPiecesIds'] = []

            if save_data['available_pieces_ids']:
                save_data['availablePiecesIds'] = json.loads(save_data['available_pieces_ids'])
            else:
                save_data['availablePiecesIds'] = []

            # 新增：解析 master_pieces 数据
            if save_data.get('master_pieces'):
                save_data['masterPieces'] = json.loads(save_data['master_pieces'])
            else:
                save_data['masterPieces'] = []

            # 重命名字段以匹配前端期望的格式
            save_data['gameMode'] = save_data['game_mode']
            save_data['elapsedSeconds'] = save_data['elapsed_seconds']
            save_data['currentScore'] = save_data['current_score']
            save_data['imageSource'] = save_data['image_source']

            # 删除原有的下划线命名字段
            del save_data['game_mode']
            del save_data['elapsed_seconds']
            del save_data['current_score']
            del save_data['image_source']
            del save_data['placed_pieces_ids']
            del save_data['available_pieces_ids']
            if 'master_pieces' in save_data:
                del save_data['master_pieces']

        except Exception as json_error:
            print(f"JSON解析错误: {json_error}")
            save_data['placedPiecesIds'] = []
            save_data['availablePiecesIds'] = []
            save_data['masterPieces'] = []  # 新增：默认空的大师模式数据
            save_data['gameMode'] = save_data.get('game_mode', 'classic')
            save_data['elapsedSeconds'] = save_data.get('elapsed_seconds', 0)
            save_data['currentScore'] = save_data.get('current_score', 0)
            save_data['imageSource'] = save_data.get('image_source', 'assets/images/default_puzzle.jpg')

        # 转换 Decimal 和 datetime 类型为 JSON 可序列化的格式
        for key, value in save_data.items():
            if isinstance(value, Decimal):
                save_data[key] = float(value)
            elif isinstance(value, datetime.datetime):
                save_data[key] = value.isoformat()

        # 添加调试信息，显示转换后的返回值
        print(f"转换后的 load_save 返回值: {save_data}")
        return jsonify(save_data), 200

    except Exception as e:
        return jsonify({'error': f'加载存档失败: {str(e)}'}), 500

@app.route('/api/delete-save', methods=['DELETE'])
@token_required
def delete_save():
    """删除游戏存档"""
    try:
        user_id = request.user['user_id']
        game_mode = request.args.get('gameMode', '').strip()
        difficulty = str(request.args.get('difficulty', '')).strip()

        if not game_mode or not difficulty:
            return jsonify({'error': '游戏模式和难度不能为空'}), 400

        # 查询匹配条件的存档
        query_conditions = ["user_id = %s", "game_mode = %s", "difficulty = %s"]
        query_params = [user_id, game_mode, difficulty]

        # 检查存档是否存在且属于当前用户
        save_exists = execute_query(
            f"SELECT id FROM game_saves WHERE {' AND '.join(query_conditions)}",
            query_params,
            fetch='one'
        )

        if not save_exists:
            return jsonify({'error': '存档不存在'}), 404

        # 删除存档
        result = execute_query(
            f"DELETE FROM game_saves WHERE {' AND '.join(query_conditions)}",
            query_params
        )

        return jsonify({'message': '存档删除成功'}), 200

    except Exception as e:
        return jsonify({'error': f'删除存档失败: {str(e)}'}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """健康检查"""
    try:
        # 测试数据库连接
        connection = get_db_connection()
        if connection:
            connection.close()
            return jsonify({'status': 'healthy', 'database': 'connected'}), 200
        else:
            return jsonify({'status': 'unhealthy', 'database': 'disconnected'}), 503
    except Exception as e:
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 503

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)