# SpringBoot Docker 自动化部署脚本
param(
    [string]$ServerIp = "49.235.161.106",
    [int]$ServerPort = 22,
    [string]$ServerUser = "root",
    [string]$TargetDir = "/opt/apps/memo-app",
    [string]$AppName = "accountingTest-app",
    [string]$AppVersion = "1.0.0",
    [int]$ContainerPort = 10013
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SpringBoot Docker 自动化部署脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤 1: 检查本地文件
Write-Host "[1/7] 检查本地文件..." -ForegroundColor Yellow
$LocalJarPath = "target/accounting-system-1.0.0.jar"
$LocalDockerfilePath = "Dockerfile"

if (-not (Test-Path $LocalJarPath)) {
    Write-Host "错误: 找不到 JAR 文件: $LocalJarPath" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $LocalDockerfilePath)) {
    Write-Host "错误: 找不到 Dockerfile: $LocalDockerfilePath" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 本地文件检查通过" -ForegroundColor Green

# 步骤 2: 准备部署文件
Write-Host "[2/7] 准备部署文件..." -ForegroundColor Yellow
Copy-Item -Path $LocalJarPath -Destination "target/kimi.jar" -Force
Write-Host "✓ JAR 文件已准备 (kimi.jar)" -ForegroundColor Green

# 步骤 3: 检查 SSH 连接
Write-Host "[3/7] 检查 SSH 连接..." -ForegroundColor Yellow
$sshTest = "echo 'SSH连接成功'"
$sshResult = $sshTest | ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p $ServerPort "${ServerUser}@${ServerIp}" "bash -s" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: SSH 连接失败，请检查密钥配置" -ForegroundColor Red
    Write-Host "请确保已配置 SSH 密钥免密登录" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ SSH 连接成功" -ForegroundColor Green

# 步骤 4: 检查服务器环境
Write-Host "[4/7] 检查服务器环境..." -ForegroundColor Yellow
$envCheck = @'
echo "=== 检查 Docker ==="
if command -v docker &> /dev/null; then
    docker --version
else
    echo "ERROR: Docker 未安装"
    exit 1
fi
echo "=== 创建目标目录 ==="
mkdir -p /opt/apps/memo-app
echo "目录准备完成"
'@
$envResult = $envCheck | ssh -o StrictHostKeyChecking=no -p $ServerPort "${ServerUser}@${ServerIp}" "bash -s" 2>&1
Write-Host $envResult
Write-Host "✓ 服务器环境检查通过" -ForegroundColor Green

# 步骤 5: 上传文件
Write-Host "[5/7] 上传文件到服务器..." -ForegroundColor Yellow
scp -P $ServerPort -o StrictHostKeyChecking=no "target/kimi.jar" "${ServerUser}@${ServerIp}:${TargetDir}/" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: JAR 文件上传失败" -ForegroundColor Red
    exit 1
}
scp -P $ServerPort -o StrictHostKeyChecking=no "Dockerfile" "${ServerUser}@${ServerIp}:${TargetDir}/" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "错误: Dockerfile 上传失败" -ForegroundColor Red
    exit 1
}
Write-Host "✓ 文件上传完成" -ForegroundColor Green

# 步骤 6: 远程部署
Write-Host "[6/7] 执行远程部署..." -ForegroundColor Yellow
$deployScript = @'
cd /opt/apps/memo-app
echo "=== 检查端口占用 ==="
CONTAINER_ID=$(docker ps -q --filter "publish=10013" 2>/dev/null)
if [ ! -z "$CONTAINER_ID" ]; then
    echo "发现端口 10013 被占用，容器ID: $CONTAINER_ID"
    echo "停止并删除旧容器..."
    docker stop $CONTAINER_ID
    docker rm $CONTAINER_ID
    echo "旧容器已清理"
else
    echo "端口 10013 未被占用"
fi

echo "=== 检查并删除旧镜像 ==="
OLD_IMAGE=$(docker images -q accountingTest-app:1.0.0 2>/dev/null)
if [ ! -z "$OLD_IMAGE" ]; then
    echo "发现旧镜像，删除中..."
    docker rmi -f $OLD_IMAGE
fi

echo "=== 构建新镜像 ==="
docker build -t accountingTest-app:1.0.0 .

echo "=== 启动新容器 ==="
docker run -d \
    --name accountingTest-app-container \
    -p 10013:10013 \
    -e JAVA_OPTS="-Xms256m -Xmx512m" \
    -e SERVER_PORT=10013 \
    -v /opt/apps/memo-app/data:/app/data \
    --restart unless-stopped \
    accountingTest-app:1.0.0

echo "=== 部署完成 ==="
docker ps --filter "name=accountingTest-app-container"
'@
$deployResult = $deployScript | ssh -o StrictHostKeyChecking=no -p $ServerPort "${ServerUser}@${ServerIp}" "bash -s" 2>&1
Write-Host $deployResult
Write-Host "✓ 远程部署执行完成" -ForegroundColor Green

# 步骤 7: 验证服务
Write-Host "[7/7] 验证服务状态..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$verifyScript = @'
echo "=== 容器状态 ==="
docker ps --filter "name=accountingTest-app-container" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "=== 最近日志 ==="
docker logs --tail 15 accountingTest-app-container 2>&1
'@
$verifyResult = $verifyScript | ssh -o StrictHostKeyChecking=no -p $ServerPort "${ServerUser}@${ServerIp}" "bash -s" 2>&1
Write-Host $verifyResult
Write-Host "✓ 服务验证完成" -ForegroundColor Green

# 输出结果
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  部署完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "应用信息:" -ForegroundColor Yellow
Write-Host "  - 应用名称: accountingTest-app" -ForegroundColor White
Write-Host "  - 版本: 1.0.0" -ForegroundColor White
Write-Host "  - 容器名称: accountingTest-app-container" -ForegroundColor White
Write-Host ""
Write-Host "访问地址:" -ForegroundColor Yellow
Write-Host "  - 首页: http://49.235.161.106:10013" -ForegroundColor Green
Write-Host "  - API文档: http://49.235.161.106:10013/api.html" -ForegroundColor Green
Write-Host ""
Write-Host "常用命令:" -ForegroundColor Yellow
Write-Host "  - 查看日志: ssh root@49.235.161.106 'docker logs -f accountingTest-app-container'" -ForegroundColor White
Write-Host "  - 重启服务: ssh root@49.235.161.106 'docker restart accountingTest-app-container'" -ForegroundColor White
Write-Host "  - 停止服务: ssh root@49.235.161.106 'docker stop accountingTest-app-container'" -ForegroundColor White
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
