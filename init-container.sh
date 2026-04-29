#!/bin/bash
# =============================================================
# init-all-containers.sh
# 用途：批量初始化所有 OpenClaw 容器，安装 sudo 并赋予 node 用户免密 root 权限
# 用法：
#   chmod +x init-all-containers.sh
#   ./init-all-containers.sh
# =============================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 统计
TOTAL=0
SUCCESS=0
FAILED=0
FAILED_LIST=""

# 获取所有使用 openclaw 镜像的运行中容器
CONTAINERS=$(docker ps --filter "ancestor=ghcr.io/openclaw/openclaw:2026.4.22" --format "{{.ID}} {{.Names}}" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    echo -e "${RED}❌ 未找到任何运行中的 OpenClaw 容器${NC}"
    exit 1
fi

TOTAL=$(echo "$CONTAINERS" | wc -l)

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE} OpenClaw 容器批量权限初始化脚本${NC}"
echo -e "${BLUE} 检测到 ${TOTAL} 个运行中的容器${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# 并发控制：最多同时处理的容器数
MAX_PARALLEL=${MAX_PARALLEL:-5}
RUNNING=0

# 临时目录存放每个容器的执行结果
RESULT_DIR=$(mktemp -d)
trap "rm -rf $RESULT_DIR" EXIT

# 单个容器的初始化函数
init_container() {
    local CONTAINER_ID="$1"
    local CONTAINER_NAME="$2"
    local RESULT_FILE="${RESULT_DIR}/${CONTAINER_ID}"

    (
        echo "STARTED" > "$RESULT_FILE"

        # Step 1: 更新 apt 源
        if ! docker exec -u root "$CONTAINER_ID" bash -c \
            "apt-get update -qq" >/dev/null 2>&1; then
            echo "FAIL:apt-get update 失败" > "$RESULT_FILE"
            return
        fi

        # Step 2: 安装 sudo
        if ! docker exec -u root "$CONTAINER_ID" bash -c \
            "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sudo" >/dev/null 2>&1; then
            echo "FAIL:sudo 安装失败" > "$RESULT_FILE"
            return
        fi

        # Step 3: 配置 node 用户免密 sudo
        if ! docker exec -u root "$CONTAINER_ID" bash -c \
            "echo 'node ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/node && \
             chmod 0440 /etc/sudoers.d/node && \
             visudo -c" >/dev/null 2>&1; then
            echo "FAIL:sudoers 配置失败" > "$RESULT_FILE"
            return
        fi

        # Step 4: 验证
        VERIFY=$(docker exec -u node "$CONTAINER_ID" sudo whoami 2>&1)
        if [ "$VERIFY" = "root" ]; then
            echo "OK" > "$RESULT_FILE"
        else
            echo "FAIL:验证失败 (whoami=$VERIFY)" > "$RESULT_FILE"
        fi
    ) &
}

# 遍历所有容器，并发执行
echo -e "${YELLOW}开始初始化（最大并发: ${MAX_PARALLEL}）...${NC}"
echo ""

while IFS=' ' read -r CID CNAME; do
    # 并发控制
    while [ "$(jobs -rp | wc -l)" -ge "$MAX_PARALLEL" ]; do
        sleep 0.5
    done

    printf "  ⏳ %-20s (%s) 初始化中...\n" "$CNAME" "${CID:0:12}"
    init_container "$CID" "$CNAME"

done <<< "$CONTAINERS"

# 等待所有后台任务完成
echo ""
echo -e "${YELLOW}等待所有容器初始化完成...${NC}"
wait
echo ""

# 汇总结果
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE} 执行结果${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

while IFS=' ' read -r CID CNAME; do
    RESULT_FILE="${RESULT_DIR}/${CID}"
    if [ -f "$RESULT_FILE" ]; then
        RESULT=$(cat "$RESULT_FILE")
        if [ "$RESULT" = "OK" ]; then
            printf "  ${GREEN}✅ %-20s (%s) 成功${NC}\n" "$CNAME" "${CID:0:12}"
            SUCCESS=$((SUCCESS + 1))
        else
            REASON="${RESULT#FAIL:}"
            printf "  ${RED}❌ %-20s (%s) 失败: %s${NC}\n" "$CNAME" "${CID:0:12}" "$REASON"
            FAILED=$((FAILED + 1))
            FAILED_LIST="${FAILED_LIST}\n    - ${CNAME} (${CID:0:12}): ${REASON}"
        fi
    else
        printf "  ${RED}❌ %-20s (%s) 失败: 无结果文件${NC}\n" "$CNAME" "${CID:0:12}"
        FAILED=$((FAILED + 1))
    fi
done <<< "$CONTAINERS"

echo ""
echo -e "${BLUE}==========================================${NC}"
echo -e "  总计: ${TOTAL}  ${GREEN}成功: ${SUCCESS}${NC}  ${RED}失败: ${FAILED}${NC}"
echo -e "${BLUE}==========================================${NC}"

if [ "$FAILED" -gt 0 ]; then
    echo ""
    echo -e "${RED}失败的容器:${FAILED_LIST}${NC}"
    echo ""
fi

echo ""
echo -e "${GREEN}使用方式：${NC}"
echo "  docker exec -it <容器名> bash"
echo "  sudo apt-get install -y <你需要的包>"
echo "  sudo bash   # 切换到 root shell"
echo ""

# 如果有失败的返回非零退出码
[ "$FAILED" -eq 0 ] || exit 1