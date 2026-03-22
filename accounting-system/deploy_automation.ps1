<#
================================================================================
                    SpringBoot 应用 Docker 自动化部署脚本
================================================================================
功能：
    1. 本地 Maven 打包（jar包名称：dogFooding.jar）
    2. 创建/更新 Dockerfile
    3. 服务器环境检测
    4. 上传文件到服务器
    5. 远程构建 Docker 镜像
    6. 端口占用检测与处理
    7. 部署与启动容器
    8. 服务验证与状态输出

服务器信息：
    - IP: 49.235.161.106
    - SSH端口: 22
    - 用户名: root
    - 目标目录: /opt/apps/memo-app

应用信息：
    - 应用名称: accountingTest-app
    - 版本: 1.0.0
    - 服务端口: 10011
    - JVM参数: -Xms256m -Xmx512m
================================================================================
#>

# ============== 配置区域 ==============
$CONFIG = @{
    SERVER_IP        = "49.235.161.106"
    SSH_PORT         = "22"
    SSH_USER         = "root"
    TARGET_DIR       = "/opt/apps/memo-app"
    APP_NAME         = "accountingtest-app"
    APP_VERSION      = "1.0.0"
    JAR_FILE         = "dogFooding.jar"
    SERVICE_PORT     = "10011"
    JVM_OPTS         = "-Xms256m -Xmx512m"
    LOCAL_PROJECT    = $PWD.Path
}
# =====================================

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "SUCCESS" { [ConsoleColor]::Green }
        "ERROR" { [ConsoleColor]::Red }
        "WARNING" { [ConsoleColor]::Yellow }
        default { [ConsoleColor]::Cyan }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Exit-WithError {
    param([string]$Message)
    Write-Log $Message "ERROR"
    exit 1
}

Write-Log "=================================================="
Write-Log "    SpringBoot Docker 自动化部署开始"
Write-Log "=================================================="

# 步骤1: 检查并更新配置文件
Write-Log "步骤1/9: 检查并更新配置文件"

$appYmlPath = Join-Path $CONFIG.LOCAL_PROJECT "src\main\resources\application.yml"
if (Test-Path $appYmlPath) {
    $content = Get-Content $appYmlPath -Raw
    if ($content -match 'port:\s+\d+') {
        $content = $content -replace 'port:\s+\d+', "port: $($CONFIG.SERVICE_PORT)"
        Set-Content $appYmlPath -Value $content -NoNewline
        Write-Log "已更新 application.yml 端口为 $($CONFIG.SERVICE_PORT)" "SUCCESS"
    }
}
else {
    Exit-WithError "未找到 application.yml 文件"
}

# 步骤2: 检查并更新pom.xml
Write-Log "步骤2/9: 检查并更新 pom.xml"
$pomPath = Join-Path $CONFIG.LOCAL_PROJECT "pom.xml"
if (Test-Path $pomPath) {
    $content = Get-Content $pomPath -Raw
    # 确保Java版本兼容
    if ($content -match '<java.version>11</java.version>') {
        $content = $content -replace '<java.version>11</java.version>', '<java.version>1.8</java.version>'
        Write-Log "已将Java版本从11更新为1.8以兼容服务器环境"
    }
    # 确保finalName存在
    if ($content -notmatch '<finalName>dogFooding</finalName>') {
        $content = $content -replace '(<build>\s*)', "`$1`n        <finalName>dogFooding</finalName>"
        Write-Log "已设置 jar 包名称为 dogFooding"
    }
    Set-Content $pomPath -Value $content -NoNewline
    Write-Log "pom.xml 检查完成" "SUCCESS"
}
else {
    Exit-WithError "未找到 pom.xml 文件"
}

# 步骤3: Maven打包
Write-Log "步骤3/9: 执行 Maven 打包"
$jarPath = Join-Path $CONFIG.LOCAL_PROJECT "target\$($CONFIG.JAR_FILE)"
if (Test-Path $jarPath) {
    Write-Log "发现已存在的 jar 包，跳过打包（如需重新打包请删除 target 目录）" "WARNING"
}
else {
    Write-Log "开始执行 Maven 打包（跳过测试）..."
    try {
        Push-Location $CONFIG.LOCAL_PROJECT
        mvn clean package -DskipTests
        Pop-Location
        
        if (Test-Path $jarPath) {
            $jarSize = [math]::Round((Get-Item $jarPath).Length / 1MB, 2)
            Write-Log "Jar 包打包成功: $jarPath ($jarSize MB)" "SUCCESS"
        }
        else {
            Exit-WithError "Maven 打包失败，未生成 jar 包"
        }
    }
    catch {
        Exit-WithError "Maven 打包异常: $_"
    }
}

# 步骤4: 创建/更新 Dockerfile
Write-Log "步骤4/9: 创建/更新 Dockerfile"
$dockerfilePath = Join-Path $CONFIG.LOCAL_PROJECT "Dockerfile"
$dockerfileContent = @"
FROM openjdk:8-jre-alpine

WORKDIR /app

COPY dogFooding.jar /app/app.jar

# 安装必要工具和时区数据
RUN apk add --no-cache tzdata curl

# 设置时区为 Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone

# 暴露服务端口
EXPOSE $($CONFIG.SERVICE_PORT)

# 启动命令（直接指定JVM参数）
ENTRYPOINT java $($CONFIG.JVM_OPTS) -jar app.jar
"@
Set-Content $dockerfilePath -Value $dockerfileContent -NoNewline
Write-Log "Dockerfile 已创建/更新" "SUCCESS"

# 步骤5: 检测服务器环境
Write-Log "步骤5/9: 检测服务器环境"
try {
    Write-Log "测试 SSH 连接..."
    $connectTest = ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP "echo '连接成功'" 2>&1
    if ($connectTest -match '连接成功') {
        Write-Log "SSH 连接成功" "SUCCESS"
    }
    else {
        Exit-WithError "SSH 连接失败，请检查密钥配置"
    }

    Write-Log "检测 Docker 环境..."
    $dockerVersion = ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP "docker --version 2>&1"
    if ($dockerVersion -match 'Docker version') {
        Write-Log "Docker 已安装: $dockerVersion" "SUCCESS"
    }
    else {
        Write-Log "Docker 未安装，开始安装..." "WARNING"
        ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP "curl -fsSL https://get.docker.com | bash && systemctl start docker && systemctl enable docker"
        Write-Log "Docker 安装完成" "SUCCESS"
    }

    Write-Log "检测目标目录..."
    ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP "mkdir -p $($CONFIG.TARGET_DIR) && mkdir -p $($CONFIG.TARGET_DIR)/data"
    Write-Log "目标目录已准备: $($CONFIG.TARGET_DIR)" "SUCCESS"
}
catch {
    Exit-WithError "服务器环境检测失败: $_"
}

# 步骤6: 上传文件到服务器
Write-Log "步骤6/9: 上传文件到服务器"
try {
    Write-Log "上传 jar 包..."
    scp -P $CONFIG.SSH_PORT $jarPath $($CONFIG.SSH_USER)@$($CONFIG.SERVER_IP):$($CONFIG.TARGET_DIR)/
    
    Write-Log "上传 Dockerfile..."
    scp -P $CONFIG.SSH_PORT $dockerfilePath $($CONFIG.SSH_USER)@$($CONFIG.SERVER_IP):$($CONFIG.TARGET_DIR)/
    
    Write-Log "文件上传完成" "SUCCESS"
}
catch {
    Exit-WithError "文件上传失败: $_"
}

# 步骤7: 远程构建 Docker 镜像
Write-Log "步骤7/9: 远程构建 Docker 镜像"
$buildCmd = @"
cd $($CONFIG.TARGET_DIR)
echo "开始构建镜像: $($CONFIG.APP_NAME):$($CONFIG.APP_VERSION)"
docker build -t $($CONFIG.APP_NAME):$($CONFIG.APP_VERSION) .
if [ \$? -eq 0 ]; then
    echo "镜像构建成功"
    docker images | grep $($CONFIG.APP_NAME)
else
    echo "镜像构建失败"
    exit 1
fi
"@
try {
    ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP $buildCmd
    Write-Log "Docker 镜像构建完成" "SUCCESS"
}
catch {
    Exit-WithError "镜像构建失败: $_"
}

# 步骤8: 部署与启动容器
Write-Log "步骤8/9: 部署与启动容器"
$deployCmd = @"
cd $($CONFIG.TARGET_DIR)

echo "检查并停止占用端口 $($CONFIG.SERVICE_PORT) 的容器..."
OLD_CONTAINER=\$(docker ps -q --filter "publish=$($CONFIG.SERVICE_PORT)/tcp")
if [ ! -z "\$OLD_CONTAINER" ]; then
    echo "发现端口被占用，停止容器: \$OLD_CONTAINER"
    docker stop \$OLD_CONTAINER
    docker rm \$OLD_CONTAINER
fi

echo "检查并删除同名容器..."
EXIST_CONTAINER=\$(docker ps -aq --filter "name=$($CONFIG.APP_NAME)")
if [ ! -z "\$EXIST_CONTAINER" ]; then
    echo "发现同名容器，删除: \$EXIST_CONTAINER"
    docker stop \$EXIST_CONTAINER 2>/dev/null
    docker rm \$EXIST_CONTAINER 2>/dev/null
fi

echo "清理旧镜像（可选）..."
OLD_IMAGES=\$(docker images -q $($CONFIG.APP_NAME) | grep -v \$(docker images -q $($CONFIG.APP_NAME):$($CONFIG.APP_VERSION)) 2>/dev/null || true)
if [ ! -z "\$OLD_IMAGES" ]; then
    echo "删除旧镜像: \$OLD_IMAGES"
    docker rmi \$OLD_IMAGES 2>/dev/null || true
fi

echo "启动新容器..."
docker run -d \\
    --name $($CONFIG.APP_NAME) \\
    --restart=always \\
    -p $($CONFIG.SERVICE_PORT):$($CONFIG.SERVICE_PORT) \\
    -v $($CONFIG.TARGET_DIR)/data:/app/data \\
    $($CONFIG.APP_NAME):$($CONFIG.APP_VERSION)

if [ \$? -eq 0 ]; then
    echo "容器启动成功"
else
    echo "容器启动失败"
    exit 1
fi

echo "等待容器初始化..."
sleep 10
"@
try {
    ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP $deployCmd
    Write-Log "容器部署命令执行完成" "SUCCESS"
}
catch {
    Write-Log "容器部署可能有异常，请检查日志" "WARNING"
}

# 步骤9: 验证服务状态
Write-Log "步骤9/9: 验证服务状态"
$verifyCmd = @"
echo "=== 容器状态 ==="
docker ps --filter name=$($CONFIG.APP_NAME)

echo ""
echo "=== 应用日志（最后20行） ==="
docker logs $($CONFIG.APP_NAME) 2>&1 | tail -20

echo ""
echo "=== 服务可用性检测 ==="
sleep 5
HTTP_STATUS=\$(curl -s -o /dev/null -w "%{http_code}" -m 10 http://localhost:$($CONFIG.SERVICE_PORT)/ 2>/dev/null || echo "000")
if [ "\$HTTP_STATUS" = "200" ] || [ "\$HTTP_STATUS" = "404" ]; then
    echo "服务已启动（HTTP状态码: \$HTTP_STATUS）"
    echo ""
    echo "=================================================="
    echo "  应用访问地址: http://$($CONFIG.SERVER_IP):$($CONFIG.SERVICE_PORT)/"
    echo "=================================================="
else
    echo "服务检测失败（HTTP状态码: \$HTTP_STATUS）"
    echo "请检查容器日志或手动访问验证"
fi
"@
try {
    ssh -p $CONFIG.SSH_PORT $CONFIG.SSH_USER@$CONFIG.SERVER_IP $verifyCmd
}
catch {
    Write-Log "服务验证失败，但容器可能仍在启动中" "WARNING"
}

Write-Log "=================================================="
Write-Log "    部署流程完成！" "SUCCESS"
Write-Log "=================================================="
Write-Log ""
Write-Log "应用信息汇总:"
Write-Log "  - 应用名称: $($CONFIG.APP_NAME):$($CONFIG.APP_VERSION)"
Write-Log "  - 访问地址: http://$($CONFIG.SERVER_IP):$($CONFIG.SERVICE_PORT)/"
Write-Log "  - 管理命令:"
Write-Log "    查看日志: ssh root@$($CONFIG.SERVER_IP) 'docker logs $($CONFIG.APP_NAME)'"
Write-Log "    重启服务: ssh root@$($CONFIG.SERVER_IP) 'docker restart $($CONFIG.APP_NAME)'"
Write-Log "    停止服务: ssh root@$($CONFIG.SERVER_IP) 'docker stop $($CONFIG.APP_NAME)'"
Write-Log ""
