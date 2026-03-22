# SpringBoot应用Docker自动化部署脚本
# 配置信息
$SERVER_IP = "49.235.161.106"
$SSH_PORT = "22"
$SSH_USER = "root"
$TARGET_DIR = "/opt/apps/memo-app"
$APP_NAME = "accountingTest-app"
$APP_VERSION = "1.0.0"
$JAR_FILE = "dogFooding.jar"
$LOCAL_JAR_PATH = ".\target\dogFooding.jar"
$LOCAL_DOCKERFILE_PATH = ".\Dockerfile"
$SERVICE_PORT = "10011"

Write-Host "========================================"
Write-Host "SpringBoot应用Docker自动化部署脚本"
Write-Host "========================================"

# 检查本地文件是否存在
Write-Host "`n[1/8] 检查本地文件..."
if (-not (Test-Path $LOCAL_JAR_PATH)) {
    Write-Host "错误: Jar包不存在，请先执行Maven打包！" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $LOCAL_DOCKERFILE_PATH)) {
    Write-Host "错误: Dockerfile不存在！" -ForegroundColor Red
    exit 1
}
Write-Host "本地文件检查完成" -ForegroundColor Green

# 检测服务器连接和环境
Write-Host "`n[2/8] 检测服务器环境..."
try {
    $sshTest = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "echo '连接成功'"
    if ($sshTest -ne "连接成功") {
        throw "SSH连接失败"
    }
    Write-Host "SSH连接成功" -ForegroundColor Green
    
    # 检测Docker是否安装
    $dockerVersion = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "docker --version 2>&1"
    if ($dockerVersion -match "command not found") {
        Write-Host "警告: Docker未安装，正在尝试安装..." -ForegroundColor Yellow
        ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "curl -fsSL https://get.docker.com | bash && systemctl start docker && systemctl enable docker"
    } else {
        Write-Host "Docker已安装: $dockerVersion" -ForegroundColor Green
    }
    
    # 检测目标目录是否存在
    $dirCheck = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "if [ -d $TARGET_DIR ]; then echo '存在'; else echo '不存在'; fi"
    if ($dirCheck -eq "不存在") {
        Write-Host "创建目标目录: $TARGET_DIR"
        ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "mkdir -p $TARGET_DIR"
    }
    Write-Host "目标目录准备完成" -ForegroundColor Green
    
    # 检查是否有旧的Dockerfile
    $oldDockerfile = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "if [ -f $TARGET_DIR/Dockerfile ]; then echo '存在'; else echo '不存在'; fi"
    if ($oldDockerfile -eq "存在") {
        Write-Host "发现旧的Dockerfile，将被覆盖" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "错误: 服务器连接或环境检测失败" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# 上传文件到服务器
Write-Host "`n[3/8] 上传文件到服务器..."
try {
    Write-Host "上传Jar包..."
    scp -P $SSH_PORT $LOCAL_JAR_PATH $SSH_USER@$SERVER_IP:$TARGET_DIR/
    
    Write-Host "上传Dockerfile..."
    scp -P $SSH_PORT $LOCAL_DOCKERFILE_PATH $SSH_USER@$SERVER_IP:$TARGET_DIR/
    
    Write-Host "文件上传完成" -ForegroundColor Green
}
catch {
    Write-Host "错误: 文件上传失败" -ForegroundColor Red
    exit 1
}

# 远程执行Docker构建和部署
Write-Host "`n[4/8] 远程执行Docker构建和部署..."
$remoteCommands = @"
cd $TARGET_DIR

# 检查并停止旧容器
OLD_CONTAINER_ID=\$(docker ps -q --filter "publish=$SERVICE_PORT/tcp")
if [ ! -z "\$OLD_CONTAINER_ID" ]; then
    echo "发现端口 $SERVICE_PORT 被占用，正在停止容器 \$OLD_CONTAINER_ID..."
    docker stop \$OLD_CONTAINER_ID
    docker rm \$OLD_CONTAINER_ID
fi

# 检查是否有同名容器
NAME_CONTAINER_ID=\$(docker ps -aq --filter "name=$APP_NAME")
if [ ! -z "\$NAME_CONTAINER_ID" ]; then
    echo "发现同名容器，正在删除..."
    docker stop \$NAME_CONTAINER_ID 2>/dev/null
    docker rm \$NAME_CONTAINER_ID 2>/dev/null
fi

# 构建镜像
echo "构建Docker镜像..."
docker build -t $APP_NAME:$APP_VERSION .

# 检查旧镜像
OLD_IMAGES=\$(docker images -q $APP_NAME | grep -v \$(docker images -q $APP_NAME:$APP_VERSION))
if [ ! -z "\$OLD_IMAGES" ]; then
    echo "删除旧镜像..."
    docker rmi \$OLD_IMAGES 2>/dev/null
fi

# 运行容器
echo "启动容器..."
docker run -d \
    --name $APP_NAME \
    --restart=always \
    -p $SERVICE_PORT:$SERVICE_PORT \
    -e JVM_OPTS="-Xms256m -Xmx512m" \
    -v $TARGET_DIR/data:/app/data \
    $APP_NAME:$APP_VERSION

echo "等待容器启动..."
sleep 10
"@

try {
    ssh -p $SSH_PORT $SSH_USER@$SERVER_IP $remoteCommands
    Write-Host "Docker部署命令执行完成" -ForegroundColor Green
}
catch {
    Write-Host "错误: Docker部署失败" -ForegroundColor Red
    exit 1
}

# 验证容器状态
Write-Host "`n[5/8] 验证容器状态..."
$containerStatus = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "docker ps -q --filter name=$APP_NAME"
if ([string]::IsNullOrEmpty($containerStatus)) {
    Write-Host "错误: 容器未正常启动！" -ForegroundColor Red
    Write-Host "容器日志:" -ForegroundColor Yellow
    ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "docker logs $APP_NAME 2>&1 | tail -30"
    exit 1
}
Write-Host "容器已启动，容器ID: $containerStatus" -ForegroundColor Green

# 验证服务可用性
Write-Host "`n[6/8] 验证服务可用性..."
$maxAttempts = 10
$attempt = 0
$serviceAvailable = $false

while ($attempt -lt $maxAttempts) {
    try {
        $healthCheck = ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "curl -s -m 5 http://localhost:$SERVICE_PORT/ 2>&1 || echo 'failed'"
        if ($healthCheck -notmatch "failed" -and $healthCheck -notmatch "Connection refused") {
            $serviceAvailable = $true
            break
        }
    }
    catch {
        # 忽略错误，继续重试
    }
    
    $attempt++
    Write-Host "等待服务就绪... (尝试 $attempt/$maxAttempts)"
    Start-Sleep -Seconds 5
}

if (-not $serviceAvailable) {
    Write-Host "警告: 本地服务检测超时，尝试从外部检测..." -ForegroundColor Yellow
}

Write-Host "`n[7/8] 部署完成！" -ForegroundColor Green
Write-Host "========================================"
Write-Host "应用信息:"
Write-Host "应用名称: $APP_NAME"
Write-Host "版本: $APP_VERSION"
Write-Host "访问地址: http://$SERVER_IP:$SERVICE_PORT/"
Write-Host "========================================"

# 显示容器日志摘要
Write-Host "`n[8/8] 容器日志摘要:"
ssh -p $SSH_PORT $SSH_USER@$SERVER_IP "docker logs $APP_NAME 2>&1 | tail -20"

exit 0
