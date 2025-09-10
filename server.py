from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_socketio import SocketIO, emit, join_room, leave_room
import json
import time
import hashlib
import datetime
from decimal import Decimal
from functools import wraps
import jwt
import mysql.connector
from mysql.connector import Error
import re

app = Flask(__name__)
CORS(app)  # 允许跨域请求
SECRET_KEY = 'your-secret-key-here'
app.config['SECRET_KEY'] = SECRET_KEY # 为SocketIO设置一个密钥
socketio = SocketIO(app, cors_allowed_origins="*") # 允许SocketIO跨域


# 数据库配置
DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 29871,
    'user': 'dev_user',
    'password': 'devLhx050918@',
    'database': 'jigsaw',
    'charset': 'utf8mb4'
}

online_users = {}  # 格式: { user_id: session_id }
authenticated_sids = {} # 格式: { session_id: user_payload }
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

def json_serializable(data):
    """一个辅助函数，用于转换字典中非JSON序列化的类型"""
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, datetime.datetime):
                data[k] = v.isoformat()  # 将 datetime 对象转换为字符串
            elif isinstance(v, Decimal):
                data[k] = float(v)       # 将 Decimal 对象转换为浮点数
    return data
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
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        # 兼容 HTTP Header 和 SocketIO 事件
        if 'Authorization' in request.headers:
            token = request.headers.get('Authorization')
        elif request.args.get('token'): # 兼容URL参数
            token = request.args.get('token')
        
        if not token:
            # 兼容 socketio.on 事件的第一个参数（如果它是token的话）
            if args and isinstance(args[0], str) and len(args[0]) > 50:
                 token = args[0]
            else: # 尝试从data字典中获取
                data = args[0] if args and isinstance(args[0], dict) else {}
                token = data.get('token')

        if not token:
            return jsonify({'error': '缺少token'}), 401
        
        try:
            if 'Bearer' in token:
                token = token.split(' ')[1]
        except IndexError:
            return jsonify({'error': 'token格式错误'}), 401
        
        payload = verify_token(token)
        if not payload:
            return jsonify({'error': 'token无效或已过期'}), 401
        
        # 将用户信息附加到请求对象上，方便后续使用
        request.user = payload
        return f(*args, **kwargs)
    
    return decorated
def authenticated_only(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        # 检查当前会话ID是否在我们的已认证字典中
        if request.sid not in authenticated_sids:
            # 如果未认证，可以选择静默忽略或发送错误
            print(f"拒绝未经认证的sid {request.sid} 的事件请求")
            emit('authentication_failed', {'error': '会话未认证或已过期'})
            return

        # 如果已认证，将用户信息附加到请求中，方便后续使用
        request.user = authenticated_sids[request.sid]
        return f(*args, **kwargs)
    return decorated
# ===================================================================
#                      WebSocket 实时事件处理
# ===================================================================

@socketio.on('connect')
def handle_connect():
    """客户端连接成功"""
    print(f'客户端连接成功, sid: {request.sid}')

@socketio.on('authenticate')
def handle_authenticate(data):
    """客户端连接后发送token进行认证"""
    token = data.get('token')
    payload = verify_token(token)
    if payload:
        user_id = payload['user_id']
        online_users[user_id] = request.sid
        authenticated_sids[request.sid] = payload
        join_room(str(user_id))  # 每个用户进入以自己ID命名的房间，方便定向通知
        print(f"用户 {user_id} ({payload['username']}) 已认证上线, sid: {request.sid}")
        # 通知该用户的好友，他上线了
        friends = get_user_friends_list(user_id)
        for friend in friends:
            if friend['id'] in online_users:
                emit('friend_status_update', {'user_id': user_id, 'status': 'online'}, room=str(friend['id']))
        emit('authentication_success', {'user_id': user_id})
    else:
        emit('authentication_failed', {'error': '无效的token'})


@socketio.on('disconnect')
def handle_disconnect():
    """客户端断开连接"""
    # ▼▼▼ 新增：从我们的新字典中移除断开连接的会话 ▼▼▼
    if request.sid in authenticated_sids:
        disconnected_user_payload = authenticated_sids.pop(request.sid)
        user_id_to_notify = disconnected_user_payload['user_id']

        # 从 online_users 也移除
        if user_id_to_notify in online_users:
            del online_users[user_id_to_notify]

        print(f"用户 {user_id_to_notify} ({disconnected_user_payload['username']}) 已下线")
        # 通知好友下线 (这部分逻辑可以保持)
        friends = get_user_friends_list(user_id_to_notify)
        for friend in friends:
            if friend['id'] in online_users:
                emit('friend_status_update', {'user_id': user_id_to_notify, 'status': 'offline'}, room=str(friend['id']))
    else:
        print(f"一个未经认证的会话 {request.sid} 断开了连接")


@socketio.on('invite_to_match')
@authenticated_only  # <-- 使用新装饰器
def handle_invite_to_match(data):
    """处理发起对战邀请"""
    challenger_id = request.user['user_id']
    challenger_username = request.user['username']
    opponent_id = data.get('opponent_id')
    difficulty = data.get('difficulty')
    image_source = data.get('image_source')

    if not all([opponent_id, difficulty, image_source]):
        emit('error', {'message': '邀请信息不完整'})
        return

    # 1. 在数据库创建比赛记录
    match_id = execute_query(
        "INSERT INTO matches (challenger_id, opponent_id, difficulty, image_source, status) VALUES (%s, %s, %s, %s, 'pending')",
        (challenger_id, opponent_id, difficulty, image_source)
    )

    # 2. 如果对手在线，发送实时邀请通知
    if opponent_id in online_users:
        emit('new_match_invite', {
            'match_id': match_id,
            'challenger_id': challenger_id,
            'challenger_username': challenger_username,
            'difficulty': difficulty,
            'image_source': image_source,
        }, room=str(opponent_id))
    else:
        # 对手不在线，可以考虑后续实现离线消息系统
        print(f"邀请失败：用户 {opponent_id} 不在线")
        emit('error', {'message': f'邀请失败，玩家不在线'})


@socketio.on('respond_to_invite')
@authenticated_only
def handle_respond_to_invite(data):
    """处理对战邀请的回应"""
    user_id = request.user['user_id']
    match_id = data.get('match_id')
    response = data.get('response') # 'accepted' or 'declined'

    match = execute_query("SELECT * FROM matches WHERE id = %s AND opponent_id = %s AND status = 'pending'", (match_id, user_id), fetch='one')
    if not match:
        emit('error', {'message': '无效的邀请或邀请已过期'})
        return

    challenger_id = match['challenger_id']

    if response == 'accepted':
        execute_query("UPDATE matches SET status='in_progress', started_at=CURRENT_TIMESTAMP WHERE id=%s", (match_id,))

        updated_match = execute_query("SELECT * FROM matches WHERE id=%s", (match_id,), fetch='one')

        # 2. 序列化数据
        serializable_match = json_serializable(updated_match)

        # 3. 发送一个清晰、扁平的 'match' 对象
        # 不再使用 'match_id' 和 'match_details' 的嵌套结构
        emit('match_started', {'match': serializable_match}, room=str(challenger_id))
        emit('match_started', {'match': serializable_match}, room=str(user_id))

    else: # 'declined'
        execute_query("UPDATE matches SET status='declined' WHERE id=%s", (match_id,))
        # 通知挑战者，邀请被拒绝
        emit('invite_declined', {'match_id': match_id, 'opponent_username': request.user['username']}, room=str(challenger_id))

@socketio.on('player_progress_update')
@authenticated_only
def handle_progress_update(data):
    """处理玩家游戏进度更新"""
    user_id = request.user['user_id']
    match_id = data.get('match_id')
    progress = data.get('progress') # e.g., 25.5 (百分比)
    
    match = execute_query("SELECT challenger_id, opponent_id FROM matches WHERE id = %s", (match_id,), fetch='one')
    if not match: return
    
    # 确定对手ID
    opponent_id = match['opponent_id'] if user_id == match['challenger_id'] else match['challenger_id']
    
    # 将进度转发给对手
    if opponent_id in online_users:
        emit('opponent_progress_update', {'progress': progress}, room=str(opponent_id))


@socketio.on('player_finished')
@authenticated_only
def handle_player_finished(data):
    """
    处理玩家完成拼图 (新逻辑：第一个完成者直接获胜)
    """
    user_id = request.user['user_id']
    match_id = data.get('match_id')
    time_ms = data.get('time_ms')

    if not match_id:
        print(f"无效的 'player_finished' 事件：缺少 match_id。")
        return

    # ▼▼▼ 核心逻辑修改 ▼▼▼

    # 1. 获取比赛当前状态，并检查是否已经结束
    # 这一步至关重要，防止两个玩家在毫秒级的时间差内都完成，导致逻辑冲突
    match = execute_query("SELECT * FROM matches WHERE id=%s", (match_id,), fetch='one')

    if not match:
        print(f"比赛 {match_id} 不存在。")
        return

    # 如果比赛状态不是 "in_progress"，说明已经有胜利者产生了，直接返回
    if match['status'] != 'in_progress':
        print(f"比赛 {match_id} 已结束，忽略来自玩家 {user_id} 的完成请求。")
        return

    # 2. 如果比赛仍在进行，那么当前这位玩家就是胜利者！
    winner_id = user_id

    # 3. 准备更新数据库：设置胜利者、比赛状态、完成时间等
    # 我们只更新胜利者的时间，失败者的时间将保持为 NULL
    update_column = None
    if user_id == match['challenger_id']:
        update_column = "challenger_time_ms"
    elif user_id == match['opponent_id']:
        update_column = "opponent_time_ms"
    else:
        # 理论上不会发生，但作为安全检查
        print(f"用户 {user_id} 不是比赛 {match_id} 的参与者。")
        return

    print(f"玩家 {user_id} 第一个完成比赛 {match_id}！宣布为胜利者。")

    # 在一个查询中完成所有更新，确保数据一致性
    final_update_query = f"""
        UPDATE matches
        SET
            status = 'completed',
            winner_id = %s,
            completed_at = CURRENT_TIMESTAMP,
            {update_column} = %s
        WHERE id = %s
    """
    execute_query(final_update_query, (winner_id, time_ms, match_id))

    # 4. 向双方广播比赛结束的消息
    final_result = execute_query("SELECT * FROM matches WHERE id=%s", (match_id,), fetch='one')
    serializable_result = json_serializable(final_result)

    challenger_id = match['challenger_id']
    opponent_id = match['opponent_id']

    print(f"向玩家 {challenger_id} 和 {opponent_id} 广播比赛 {match_id} 的结束结果。")
    emit('match_over', {'result': serializable_result}, room=str(challenger_id))
    emit('match_over', {'result': serializable_result}, room=str(opponent_id))

    # ▲▲▲ 核心逻辑修改结束 ▲▲▲



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

@app.route('/api/user/achievements', methods=['GET'])
@token_required
def get_user_achievements():
    """获取用户成就完成情况"""
    try:
        user_id = request.user['user_id']

        # 获取用户已完成的成就
        completed_achievements = execute_query(
            "SELECT achievement_id, completed_at FROM user_achievements WHERE user_id = %s",
            (user_id,),
            fetch='all'
        )

        # 获取用户统计数据用于判断成就完成情况
        user_stats = execute_query(
            """
            SELECT 
                -- 基础统计
                COUNT(*) as total_games,
                IFNULL(MAX(score), 0) as best_score,
                IFNULL(SUM(score), 0) as total_score,
                IFNULL(AVG(score), 0) as avg_score,
                IFNULL(MIN(time_taken), 0) as best_time,
                IFNULL(MAX(time_taken), 0) as longest_time,
                IFNULL(AVG(time_taken), 0) as avg_time,
                
                -- 难度统计
                COUNT(CASE WHEN difficulty = 'easy' THEN 1 END) as easy_completed,
                COUNT(CASE WHEN difficulty = 'medium' THEN 1 END) as medium_completed,
                COUNT(CASE WHEN difficulty = 'hard' THEN 1 END) as hard_completed,
                COUNT(CASE WHEN difficulty = 'master' THEN 1 END) as master_completed,
                
                -- 时间相关统计
                COUNT(CASE WHEN time_taken <= 15 THEN 1 END) as games_under_15s,
                COUNT(CASE WHEN time_taken <= 30 THEN 1 END) as games_under_30s,
                COUNT(CASE WHEN time_taken <= 60 THEN 1 END) as games_under_60s,
                COUNT(CASE WHEN time_taken >= 300 THEN 1 END) as games_over_5min,
                COUNT(CASE WHEN time_taken >= 600 THEN 1 END) as games_over_10min,
                
                -- 特定条件组合统计
                COUNT(CASE WHEN difficulty = 'easy' AND time_taken <= 30 THEN 1 END) as easy_under_30s,
                COUNT(CASE WHEN difficulty = 'easy' AND time_taken <= 15 THEN 1 END) as easy_under_15s,
                COUNT(CASE WHEN difficulty = 'medium' AND time_taken <= 60 THEN 1 END) as medium_under_60s,
                COUNT(CASE WHEN difficulty = 'hard' AND time_taken <= 120 THEN 1 END) as hard_under_120s,
                
                -- 分数相关统计
                COUNT(CASE WHEN score >= 1000 THEN 1 END) as high_score_games,
                COUNT(CASE WHEN score >= 5000 THEN 1 END) as very_high_score_games,
                COUNT(CASE WHEN score >= 10000 THEN 1 END) as ultra_high_score_games,
                
                -- 连续性和频率统计 (可以根据需要添加)
                MIN(created_at) as first_game_date,
                MAX(created_at) as last_game_date
            FROM scores 
            WHERE user_id = %s
            """,
            (user_id,),
            fetch='one'
        )
        
        # 添加社交相关统计（需要matches表）
        social_stats = execute_query(
            """
            SELECT 
                COUNT(DISTINCT CASE WHEN challenger_id = %s THEN opponent_id ELSE challenger_id END) as unique_opponents,
                COUNT(CASE WHEN winner_id = %s THEN 1 END) as matches_won,
                COUNT(*) as total_matches
            FROM matches 
            WHERE (challenger_id = %s OR opponent_id = %s) AND status = 'completed'
            """,
            (user_id, user_id, user_id, user_id),
            fetch='one'
        )
        
        # 合并统计数据
        if user_stats and social_stats:
            user_stats.update(social_stats)
        elif social_stats:
            user_stats = social_stats

        # 转换结果为便于前端使用的格式
        completed_list = [
            {
                'achievement_id': ach['achievement_id'],
                'completed_at': ach['completed_at'].isoformat() if ach['completed_at'] else None
            }
            for ach in (completed_achievements or [])
        ]

        return jsonify({
            'completed_achievements': completed_list,
            'user_stats': user_stats or {
                'total_games': 0,
                'best_score': 0,
                'total_score': 0,
                'best_time': 0,
                'speed_easy_count': 0,
                'hard_completed': 0,
                'lightning_count': 0,
                'marathon_count': 0
            }
        }), 200

    except Exception as e:
        return jsonify({'error': f'获取用户成就失败: {str(e)}'}), 500

@app.route('/api/user/achievements', methods=['POST'])
@token_required
def unlock_achievement():
    """解锁用户成就"""
    try:
        data = request.get_json()
        achievement_id = data.get('achievement_id')
        
        if not achievement_id:
            return jsonify({'error': '成就ID不能为空'}), 400

        user_id = request.user['user_id']

        # 检查成就是否已经解锁
        existing = execute_query(
            "SELECT id FROM user_achievements WHERE user_id = %s AND achievement_id = %s",
            (user_id, achievement_id),
            fetch='one'
        )

        if existing:
            return jsonify({'error': '成就已经解锁'}), 409

        # 解锁成就
        result = execute_query(
            "INSERT INTO user_achievements (user_id, achievement_id) VALUES (%s, %s)",
            (user_id, achievement_id)
        )

        if result:
            return jsonify({
                'message': '成就解锁成功',
                'achievement_id': achievement_id
            }), 201
        else:
            return jsonify({'error': '成就解锁失败'}), 500

    except Exception as e:
        return jsonify({'error': f'解锁成就失败: {str(e)}'}), 500


@app.route('/api/matches/history', methods=['GET'])
@token_required
def get_match_history():
    """获取用户的对战历史记录"""
    try:
        user_id = request.user['user_id']

        # 使用 UNION ALL 来合并用户作为挑战者和应战者的所有已完成比赛
        query = """
            (SELECT
                m.id, m.difficulty, m.completed_at, m.winner_id,
                opp.id as opponent_id,
                opp.username as opponent_username
            FROM matches m
            JOIN users opp ON m.opponent_id = opp.id
            WHERE m.challenger_id = %s AND m.status = 'completed')

            UNION ALL

            (SELECT
                m.id, m.difficulty, m.completed_at, m.winner_id,
                chal.id as opponent_id,
                chal.username as opponent_username
            FROM matches m
            JOIN users chal ON m.challenger_id = chal.id
            WHERE m.opponent_id = %s AND m.status = 'completed')

            ORDER BY completed_at DESC
            LIMIT 50
        """

        matches = execute_query(query, (user_id, user_id), fetch='all')

        # 处理结果，添加'result'字段，并序列化
        history = []
        for match in matches:
            # 判断输赢
            if match['winner_id'] is None:
                # 已完成的比赛理论上应该有 winner_id, 此处为健壮性检查
                match['result'] = '平局'
            elif match['winner_id'] == user_id:
                match['result'] = '胜利'
            else:
                match['result'] = '失败'

            history.append(json_serializable(match))

        return jsonify(history or []), 200

    except Exception as e:
        print(f"获取对战历史失败: {str(e)}")
        return jsonify({'error': f'获取对战历史失败: {str(e)}'}), 500

@app.route('/api/users/search', methods=['GET'])
@token_required
def search_users():
    """根据用户名或邮箱搜索用户"""
    query_str = request.args.get('query', '').strip()
    user_id = request.user['user_id']
    if len(query_str) < 2:
        return jsonify({'error': '搜索词至少需要2个字符'}), 400

    # 复杂的查询，排除自己，并找出与自己已存在的关系
    query = """
    SELECT u.id, u.username, f.status, f.action_user_id
    FROM users u
    LEFT JOIN friendships f ON (
        (f.user_one_id = u.id AND f.user_two_id = %s) OR
        (f.user_one_id = %s AND f.user_two_id = u.id)
    )
    WHERE (u.username LIKE %s OR u.email LIKE %s) AND u.id != %s
    LIMIT 10
    """
    search_term = f"%{query_str}%"
    users = execute_query(query, (user_id, user_id, search_term, search_term, user_id), fetch='all')
    return jsonify(users or []), 200

@app.route('/api/friends/request', methods=['POST'])
@token_required
def send_friend_request():
    """发送好友请求"""
    data = request.get_json()
    target_user_id = data.get('target_user_id')
    if not target_user_id:
        return jsonify({'error': '缺少目标用户ID'}), 400

    current_user_id = request.user['user_id']
    if int(target_user_id) == current_user_id:
        return jsonify({'error': '不能添加自己为好友'}), 400
    
    user_one_id = min(current_user_id, int(target_user_id))
    user_two_id = max(current_user_id, int(target_user_id))

    existing = execute_query("SELECT id FROM friendships WHERE user_one_id = %s AND user_two_id = %s", (user_one_id, user_two_id), fetch='one')
    if existing:
        return jsonify({'error': '请求已发送或已是好友'}), 409

    execute_query(
        "INSERT INTO friendships (user_one_id, user_two_id, action_user_id, status) VALUES (%s, %s, %s, 'pending')",
        (user_one_id, user_two_id, current_user_id)
    )

    # 实时通知对方
    if target_user_id in online_users:
        emit('new_friend_request', {
            'from_user_id': current_user_id,
            'from_username': request.user['username']
        }, room=str(target_user_id), namespace='/') # 确保在全局命名空间发送

    return jsonify({'message': '好友请求已发送'}), 201

def get_user_friends_list(user_id):
    """辅助函数：获取用户的好友列表"""
    query = """
        SELECT u.id, u.username FROM users u
        JOIN friendships f ON (u.id = f.user_one_id OR u.id = f.user_two_id)
        WHERE (f.user_one_id = %s OR f.user_two_id = %s)
          AND u.id != %s
          AND f.status = 'accepted'
    """
    return execute_query(query, (user_id, user_id, user_id), fetch='all')


@app.route('/api/friends', methods=['GET'])
@token_required
def get_friends():
    """获取好友列表"""
    user_id = request.user['user_id']
    friends = get_user_friends_list(user_id)
    
    # 附加在线状态
    for friend in friends:
        friend['status'] = 'online' if friend['id'] in online_users else 'offline'
        
    return jsonify(friends or []), 200

@app.route('/api/friends/requests', methods=['GET'])
@token_required
def get_friend_requests():
    """获取收到的好友请求"""
    user_id = request.user['user_id']
    query = """
        SELECT f.id as friendship_id, u.id as user_id, u.username
        FROM friendships f
        JOIN users u ON u.id = f.action_user_id
        WHERE (f.user_one_id = %s OR f.user_two_id = %s)
          AND f.status = 'pending'
          AND f.action_user_id != %s
    """
    requests = execute_query(query, (user_id, user_id, user_id), fetch='all')
    return jsonify(requests or []), 200

@app.route('/api/friends/respond', methods=['POST'])
@token_required
def respond_to_friend_request():
    """回应好友请求"""
    data = request.get_json()
    friendship_id = data.get('friendship_id')
    action = data.get('action') # 'accept' or 'decline'

    if not friendship_id or action not in ['accept', 'decline']:
        return jsonify({'error': '无效的请求'}), 400
    
    # 安全性检查：确保当前用户是该请求的接收者
    user_id = request.user['user_id']
    friendship = execute_query("SELECT * FROM friendships WHERE id = %s AND (user_one_id = %s OR user_two_id = %s) AND action_user_id != %s",
                               (friendship_id, user_id, user_id, user_id), fetch='one')
    if not friendship:
        return jsonify({'error': '好友请求不存在'}), 404

    if action == 'accept':
        execute_query("UPDATE friendships SET status = 'accepted', action_user_id = %s WHERE id = %s", (user_id, friendship_id))
        # 实时通知对方请求已被接受
        other_user_id = friendship['action_user_id']
        if other_user_id in online_users:
             emit('friend_request_accepted', {'username': request.user['username']}, room=str(other_user_id), namespace='/')
        return jsonify({'message': '已添加好友'}), 200
    else: # decline
        execute_query("DELETE FROM friendships WHERE id = %s", (friendship_id,))
        return jsonify({'message': '已拒绝请求'}), 200

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
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)