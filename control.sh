#!/bin/bash

# Mattermost Push 控制脚本
# 用于启动、停止和查看推送服务状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 容器名和目录
LISTENER_CONTAINER="mattermost-listener"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="${SCRIPT_DIR}/docker-compose-listener.yml"

# 打印帮助信息
print_help() {
    echo "用法：$0 {start|stop|restart|status|logs|logs-follow}"
    echo ""
    echo "命令说明:"
    echo "  start       - 启动推送服务（启动监听器容器）"
    echo "  stop        - 停止推送服务（停止监听器容器）"
    echo "  restart     - 重启推送服务"
    echo "  status      - 查看服务状态"
    echo "  logs        - 查看最近日志"
    echo "  logs-follow - 实时查看日志（类似 tail -f）"
    echo ""
    echo "示例:"
    echo "  $0 start        # 启动推送"
    echo "  $0 stop         # 停止推送"
    echo "  $0 logs-follow  # 实时查看日志"
}

# 检查 Docker Compose 文件
check_compose_file() {
    if [[ ! -f "${COMPOSE_FILE}" ]]; then
        echo -e "${RED}错误：找不到 Docker Compose 文件 '${COMPOSE_FILE}'${NC}"
        exit 1
    fi
}

# 启动服务
start_service() {
    echo -e "${YELLOW}正在启动 Mattermost Push 服务...${NC}"
    
    check_compose_file
    
    # 检查容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -q "^${LISTENER_CONTAINER}$"; then
        # 容器已存在，启动它
        echo "启动现有容器..."
        docker start "${LISTENER_CONTAINER}"
    else
        # 容器不存在，创建并启动
        echo "创建新容器..."
        cd "${SCRIPT_DIR}"
        docker compose -f "${COMPOSE_FILE}" up -d
    fi
    
    echo -e "${GREEN}✅ 推送服务已启动${NC}"
    echo ""
    echo "查看日志：$0 logs"
    echo "实时日志：$0 logs-follow"
}

# 停止服务
stop_service() {
    echo -e "${YELLOW}正在停止 Mattermost Push 服务...${NC}"
    
    # 检查容器是否运行
    if docker ps --format '{{.Names}}' | grep -q "^${LISTENER_CONTAINER}$"; then
        docker stop "${LISTENER_CONTAINER}"
        echo -e "${GREEN}✅ 推送服务已停止${NC}"
        echo ""
        echo "注意：容器已停止，不会接收新消息推送"
    else
        echo -e "${YELLOW}⚠️  推送服务未运行${NC}"
    fi
}

# 重启服务
restart_service() {
    echo -e "${YELLOW}正在重启 Mattermost Push 服务...${NC}"
    
    check_compose_file
    
    docker restart "${LISTENER_CONTAINER}"
    
    echo -e "${GREEN}✅ 推送服务已重启${NC}"
}

# 查看状态
check_status() {
    echo -e "${YELLOW}Mattermost Push 服务状态：${NC}"
    echo ""
    
    # 检查容器状态
    if docker ps --format '{{.Names}}\t{{.Status}}' | grep -q "^${LISTENER_CONTAINER}"; then
        STATUS=$(docker ps --format '{{.Status}}' --filter "name=${LISTENER_CONTAINER}")
        echo -e "${GREEN}● 容器运行中：${STATUS}${NC}"
        
        # 查看日志文件是否存在
        if docker exec "${LISTENER_CONTAINER}" test -f /tmp/mattermost-push-listener.log 2>/dev/null; then
            echo -e "${GREEN}● 日志文件正常${NC}"
            
            # 显示最近 5 条推送记录
            echo ""
            echo "最近推送记录:"
            docker exec "${LISTENER_CONTAINER}" tail -n 5 /tmp/mattermost-push-listener.log 2>/dev/null | sed 's/^/  /'
        else
            echo -e "${YELLOW}● 日志文件不存在（可能是首次运行）${NC}"
        fi
        
        # 显示容器信息
        echo ""
        echo "容器信息:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" | grep "${LISTENER_CONTAINER}" || true
        
    elif docker ps -a --format '{{.Names}}' | grep -q "^${LISTENER_CONTAINER}$"; then
        STATUS=$(docker ps -a --format '{{.Status}}' --filter "name=${LISTENER_CONTAINER}")
        echo -e "${YELLOW}● 容器已停止：${STATUS}${NC}"
        echo ""
        echo "启动服务：$0 start"
    else
        echo -e "${RED}● 容器不存在${NC}"
        echo ""
        echo "创建服务：$0 start"
    fi
    
    echo ""
}

# 查看最近日志
view_logs() {
    echo -e "${YELLOW}最近日志记录：${NC}"
    echo ""
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${LISTENER_CONTAINER}$"; then
        echo -e "${RED}错误：容器未运行${NC}"
        exit 1
    fi
    
    if ! docker exec "${LISTENER_CONTAINER}" test -f /tmp/mattermost-push-listener.log 2>/dev/null; then
        echo -e "${RED}日志文件不存在${NC}"
        exit 1
    fi
    
    docker exec "${LISTENER_CONTAINER}" tail -n 20 /tmp/mattermost-push-listener.log
}

# 实时查看日志
follow_logs() {
    echo -e "${YELLOW}实时查看推送日志（按 Ctrl+C 退出）...${NC}"
    echo ""
    
    if ! docker ps --format '{{.Names}}' | grep -q "^${LISTENER_CONTAINER}$"; then
        echo -e "${RED}错误：容器未运行${NC}"
        exit 1
    fi
    
    if ! docker exec "${LISTENER_CONTAINER}" test -f /tmp/mattermost-push-listener.log 2>/dev/null; then
        echo -e "${RED}日志文件不存在${NC}"
        exit 1
    fi
    
    docker exec -it "${LISTENER_CONTAINER}" tail -f /tmp/mattermost-push-listener.log
}

# 主程序
case "${1:-}" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        check_status
        ;;
    logs)
        view_logs
        ;;
    logs-follow)
        follow_logs
        ;;
    help|--help|-h|"")
        print_help
        ;;
    *)
        echo -e "${RED}错误：未知命令 '${1}'${NC}"
        print_help
        exit 1
        ;;
esac
