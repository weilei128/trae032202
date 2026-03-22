#!/bin/bash
set -e

cd /opt/apps/memo-app

echo "=== 检查端口占用 ==="
CONTAINER_ID=$(docker ps -q --filter "publish=10013" 2>/dev/null || true)
if [ ! -z "$CONTAINER_ID" ]; then
    echo "发现端口 10013 被占用，容器ID: $CONTAINER_ID"
    echo "停止并删除旧容器..."
    docker stop $CONTAINER_ID || true
    docker rm $CONTAINER_ID || true
    echo "旧容器已清理"
else
    echo "端口 10013 未被占用"
fi

echo ""
echo "=== 检查并删除旧镜像 ==="
OLD_IMAGE=$(docker images -q accountingTest-app:1.0.0 2>/dev/null || true)
if [ ! -z "$OLD_IMAGE" ]; then
    echo "发现旧镜像，删除中..."
    docker rmi -f $OLD_IMAGE || true
fi

echo ""
echo "=== 构建新镜像 ==="
docker build -t accountingTest-app:1.0.0 .

echo ""
echo "=== 启动新容器 ==="
docker run -d \
    --name accountingTest-app-container \
    -p 10013:10013 \
    -e JAVA_OPTS="-Xms256m -Xmx512m" \
    -e SERVER_PORT=10013 \
    -v /opt/apps/memo-app/data:/app/data \
    --restart unless-stopped \
    accountingTest-app:1.0.0

echo ""
echo "=== 部署完成 ==="
docker ps --filter "name=accountingTest-app-container" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
