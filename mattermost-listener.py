#!/usr/bin/env python3
"""
Mattermost 私聊消息推送监听器
监听 PostgreSQL 数据库，实时推送私聊消息到回逍
"""

import psycopg2
import requests
import time
import json
from datetime import datetime

# ========== 配置区域 ==========
CONFIG = {
    # 数据库配置（TODO: 替换为您的 Mattermost 数据库配置）
    'db_host': 'your-db-host',           # 数据库主机地址
    'db_name': 'mattermost',             # 数据库名称
    'db_user': 'your-db-user',           # 数据库用户名
    'db_password': 'your-db-password',   # 数据库密码
    
    # 回逍推送配置（TODO: 替换为您的回逍配置）
    'hui xiao_api_url': 'https://x.2im.cn/push/v2',
    'hui xiao_cid': 'YOUR_CID_HERE',     # TODO: 替换为您的回逍 CID（在 https://x.2im.cn 获取）
    'hui xiao_icon': 'https://example.com/your-icon.png',  # TODO: 替换为您自定义的图标 URL
    'hui xiao_group': 'Mattermost',
    
    # 用户过滤配置（TODO: 替换为您的用户名）
    'exclude_users': ['your_username'],  # 过滤的用户名（自己发送的消息不推送）
    
    # 日志配置
    'log_file': '/tmp/mattermost-push-listener.log'
}

def log_message(message):
    """记录日志"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    log_entry = f"{timestamp} - {message}\n"
    print(log_entry.strip())
    with open(CONFIG['log_file'], 'a', encoding='utf-8') as f:
        f.write(log_entry)

def get_db_connection():
    """获取数据库连接"""
    return psycopg2.connect(
        host=CONFIG['db_host'],
        database=CONFIG['db_name'],
        user=CONFIG['db_user'],
        password=CONFIG['db_password']
    )

def send_to_huixiao(sender_name, message, channel_type):
    """发送推送到回逍"""
    try:
        # 推送格式：标题为发件人，内容为实际消息（不添加时间戳）
        push_data = {
            'cid': CONFIG['hui xiao_cid'],
            'group': CONFIG['hui xiao_group'],
            'title': f'📬 {sender_name}',  # 标题显示发件人
            'content': message,  # 内容显示完整消息（不添加时间戳）
            'icon': CONFIG['hui xiao_icon']
        }
        
        response = requests.post(
            CONFIG['hui xiao_api_url'],
            json=push_data,
            headers={'Content-Type': 'application/json'},
            timeout=10
        )
        
        log_message(f"Push result: HTTP {response.status_code} - {response.text}")
        return response.status_code == 200
        
    except Exception as e:
        log_message(f"Push error: {str(e)}")
        return False

def listen_for_messages():
    """监听新消息"""
    log_message("Starting Mattermost message listener...")
    
    last_post_id = ""
    consecutive_errors = 0
    
    while True:
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            
            # 查询最新的私聊消息（DM 或 GM）
            query = """
                SELECT p.id, p.message, p.userid, u.username, c.type
                FROM Posts p
                JOIN Users u ON p.userid = u.id
                JOIN Channels c ON p.channelid = c.id
                WHERE c.type IN ('D', 'G')
                ORDER BY p.createat DESC
                LIMIT 1
            """
            
            cur.execute(query)
            row = cur.fetchone()
            
            if row:
                post_id, message, user_id, username, channel_type = row
                
                # 检查是否是新消息
                if post_id != last_post_id:
                    log_message(f"New message from {username}: {message[:50]}...")
                    
                    # 检查是否是排除的用户
                    if username not in CONFIG['exclude_users']:
                        log_message(f"Sending push for message from {username}: {message[:50]}...")
                        send_to_huixiao(username, message, channel_type)
                    else:
                        log_message(f"Skipped - message from excluded user: {username}")
                    
                    last_post_id = post_id
            
            cur.close()
            conn.close()
            consecutive_errors = 0
            
        except Exception as e:
            consecutive_errors += 1
            log_message(f"Error (count: {consecutive_errors}): {str(e)}")
            
            if consecutive_errors >= 5:
                log_message("Too many consecutive errors, waiting longer...")
                time.sleep(10)
            else:
                time.sleep(2)
        
        # 每 2 秒检查一次
        time.sleep(2)

if __name__ == '__main__':
    try:
        listen_for_messages()
    except KeyboardInterrupt:
        log_message("Listener stopped by user")
    except Exception as e:
        log_message(f"Fatal error: {str(e)}")
