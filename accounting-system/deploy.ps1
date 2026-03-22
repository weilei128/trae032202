# SpringBoot Docker 容器化部署脚本 (Windows PowerShell)
# 应用名称: accountingTest-app
# 版本: 1.0.0
# 服务器: 49.235.161.106
# 端口: 10012

# ==================== 配置区域 ====================
$SERVER_IP = "49.235.161.106"
$SERVER_USER = "root"
$REMOTE_DIR = "/opt/apps/memo-app"
$APP_NAME = "accountingtest-app"
$APP_VERSION = "1.0.0"
$APP_PORT = "10012"
$JAR_NAME = "GLM.jar"
$JVM_OPTS = "-Xms256m -Xmx512m"

# 本地路径
$LOCAL_PROJECT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$LOCAL_JAR_PATH = Join-Path $LOCAL_PROJECT_DIR "target\$JAR_NAME"
$LOCAL_DOCKERFILE_PATH = Join-Path $LOCAL_PROJECT_DIR "Dockerfile"

# ==================== 函数定义 ====================

function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Maven 打包
function Maven-Build {
    Log-Info "开始 Maven 打包..."
    
    Set-Location $LOCAL_PROJECT_DIR
    mvn clean package -DskipTests
    
    $ORIGINAL_JAR = Join-Path $LOCAL_PROJECT_DIR "target\accounting-system-$APP_VERSION.jar"
    if (Test-Path $ORIGINAL_JAR) {
        Copy-Item $ORIGINAL_JAR $LOCAL_JAR_PATH -Force
        Log-Info "JAR 包已生成: $LOCAL_JAR_PATH"
    } else {
        Log-Error "JAR 包生成失败"
        exit 1
    }
}

# 检查服务器环境
function Check-ServerEnv {
    Log-Info "检查服务器环境..."
    
    $result = ssh ${SERVER_USER}@${SERVER_IP} "docker --version"
    if ($LASTEXITCODE -ne 0) {
        Log-Error "服务器未安装 Docker"
        exit 1
    }
    
    ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${REMOTE_DIR}/data"
    
    Log-Info "服务器环境检查通过"
}

# 上传文件
function Upload-Files {
    Log-Info "上传 JAR 包和 Dockerfile..."
    
    scp $LOCAL_JAR_PATH "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/${JAR_NAME}"
    scp $LOCAL_DOCKERFILE_PATH "${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/Dockerfile"
    
    Log-Info "文件上传完成"
}

# 构建 Docker 镜像
function Build-Image {
    Log-Info "构建 Docker 镜像..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "cd ${REMOTE_DIR} && docker build -t ${APP_NAME}:${APP_VERSION} -t ${APP_NAME}:latest ."
    
    Log-Info "Docker 镜像构建完成"
}

# 运行容器
function Run-Container {
    Log-Info "运行 Docker 容器..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "docker rm -f ${APP_NAME} 2>/dev/null; docker run -d --name ${APP_NAME} -p ${APP_PORT}:${APP_PORT} -v ${REMOTE_DIR}/data:/app/data --restart=unless-stopped ${APP_NAME}:latest"
    
    Log-Info "容器启动完成"
}

# 验证服务
function Verify-Service {
    Log-Info "验证服务状态..."
    
    Start-Sleep -Seconds 5
    
    $containerStatus = ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter name=${APP_NAME} --format '{{.Status}}'"
    Log-Info "容器运行状态: $containerStatus"
    
    $httpCode = ssh ${SERVER_USER}@${SERVER_IP} "curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}/"
    
    if ($httpCode -eq "200") {
        Log-Info "服务响应正常 (HTTP $httpCode)"
    } else {
        Log-Warn "服务响应异常 (HTTP $httpCode)"
    }
}

# 输出访问信息
function Print-AccessInfo {
    Write-Host ""
    Write-Host "=========================================="
    Write-Host "部署完成！"
    Write-Host "=========================================="
    Write-Host "应用名称: accountingTest-app"
    Write-Host "应用版本: $APP_VERSION"
    Write-Host "访问地址: http://${SERVER_IP}:${APP_PORT}/"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "常用命令:"
    Write-Host "  查看日志: ssh ${SERVER_USER}@${SERVER_IP} 'docker logs -f ${APP_NAME}'"
    Write-Host "  重启容器: ssh ${SERVER_USER}@${SERVER_IP} 'docker restart ${APP_NAME}'"
    Write-Host "  停止容器: ssh ${SERVER_USER}@${SERVER_IP} 'docker stop ${APP_NAME}'"
    Write-Host "=========================================="
}

# ==================== 主流程 ====================

Write-Host ""
Write-Host "=========================================="
Write-Host "  SpringBoot Docker 容器化部署"
Write-Host "=========================================="
Write-Host ""

Maven-Build
Check-ServerEnv
Upload-Files
Build-Image
Run-Container
Verify-Service
Print-AccessInfo
