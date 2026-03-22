#!/bin/bash
# Mattermost Push 部署脚本

set -e

echo "=== Mattermost Push 部署脚本 ==="
echo ""

# 检查 Mattermost 容器是否运行
if ! docker ps | grep -q mattermost-mattermost; then
    echo "❌ 错误：Mattermost 容器未运行"
    exit 1
fi

echo "✓ Mattermost 容器运行正常"

# 启动监听器容器
echo ""
echo "正在启动推送监听器..."
docker compose up -d

# 等待容器启动
sleep 5

# 检查状态
if docker ps | grep -q mattermost-listener; then
    echo "✅ 部署完成！"
    echo ""
    echo "查看监听器状态:"
    echo "  docker ps | grep mattermost-listener"
    echo ""
    echo "查看推送日志:"
    echo "  docker exec mattermost-listener cat /tmp/mattermost-push-listener.log"
    echo ""
    echo "实时日志:"
    echo "  docker exec mattermost-listener tail -f /tmp/mattermost-push-listener.log"
else
    echo "❌ 部署失败，请检查日志"
    exit 1
fi
