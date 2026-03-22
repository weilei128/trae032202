#!/bin/bash
# SpringBoot Docker 容器化部署脚本
# 应用名称: accountingTest-app
# 版本: 1.0.0
# 服务器: 49.235.161.106
# 端口: 10012

set -e

# ==================== 配置区域 ====================
SERVER_IP="49.235.161.106"
SERVER_USER="root"
SERVER_PORT="22"
REMOTE_DIR="/opt/apps/memo-app"
APP_NAME="accountingtest-app"
APP_VERSION="1.0.0"
APP_PORT="10012"
JAR_NAME="GLM.jar"
JVM_OPTS="-Xms256m -Xmx512m"

# 本地路径（根据实际情况修改）
LOCAL_PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_JAR_PATH="${LOCAL_PROJECT_DIR}/target/${JAR_NAME}"
LOCAL_DOCKERFILE_PATH="${LOCAL_PROJECT_DIR}/Dockerfile"

# ==================== 颜色输出 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ==================== 函数定义 ====================

# 检查本地环境
check_local_env() {
    log_info "检查本地环境..."
    
    if ! command -v mvn &> /dev/null; then
        log_error "Maven 未安装，请先安装 Maven"
        exit 1
    fi
    
    if ! command -v scp &> /dev/null || ! command -v ssh &> /dev/null; then
        log_error "SSH 客户端未安装"
        exit 1
    fi
    
    log_info "本地环境检查通过"
}

# Maven 打包
maven_build() {
    log_info "开始 Maven 打包..."
    
    cd "${LOCAL_PROJECT_DIR}"
    mvn clean package -DskipTests
    
    # 复制并重命名 jar 包
    ORIGINAL_JAR="${LOCAL_PROJECT_DIR}/target/accounting-system-${APP_VERSION}.jar"
    if [ -f "${ORIGINAL_JAR}" ]; then
        cp "${ORIGINAL_JAR}" "${LOCAL_JAR_PATH}"
        log_info "JAR 包已生成: ${LOCAL_JAR_PATH}"
    else
        log_error "JAR 包生成失败"
        exit 1
    fi
}

# 检查服务器环境
check_server_env() {
    log_info "检查服务器环境..."
    
    # 检查 Docker
    if ! ssh ${SERVER_USER}@${SERVER_IP} "docker --version" &> /dev/null; then
        log_error "服务器未安装 Docker"
        exit 1
    fi
    
    # 创建目标目录
    ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${REMOTE_DIR}/data"
    
    log_info "服务器环境检查通过"
}

# 上传文件
upload_files() {
    log_info "上传 JAR 包和 Dockerfile..."
    
    scp "${LOCAL_JAR_PATH}" ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/${JAR_NAME}
    scp "${LOCAL_DOCKERFILE_PATH}" ${SERVER_USER}@${SERVER_IP}:${REMOTE_DIR}/Dockerfile
    
    log_info "文件上传完成"
}

# 构建 Docker 镜像
build_image() {
    log_info "构建 Docker 镜像..."
    
    ssh ${SERVER_USER}@${SERVER_IP} << EOF
        cd ${REMOTE_DIR}
        
        # 删除旧镜像（如果存在）
        docker rmi ${APP_NAME}:${APP_VERSION} 2>/dev/null || true
        docker rmi ${APP_NAME}:latest 2>/dev/null || true
        
        # 构建新镜像
        docker build -t ${APP_NAME}:${APP_VERSION} -t ${APP_NAME}:latest .
EOF
    
    log_info "Docker 镜像构建完成"
}

# 运行容器
run_container() {
    log_info "运行 Docker 容器..."
    
    ssh ${SERVER_USER}@${SERVER_IP} << EOF
        # 检查端口是否被占用，如果被占用则停止对应容器
        CONTAINER_ON_PORT=\$(docker ps -a --format '{{.Names}} {{.Ports}}' | grep ${APP_PORT} | awk '{print \$1}')
        if [ -n "\$CONTAINER_ON_PORT" ]; then
            echo "停止占用端口 ${APP_PORT} 的容器: \$CONTAINER_ON_PORT"
            docker stop \$CONTAINER_ON_PORT 2>/dev/null || true
            docker rm \$CONTAINER_ON_PORT 2>/dev/null || true
        fi
        
        # 删除同名旧容器
        docker rm -f ${APP_NAME} 2>/dev/null || true
        
        # 运行新容器
        docker run -d \
            --name ${APP_NAME} \
            -p ${APP_PORT}:${APP_PORT} \
            -v ${REMOTE_DIR}/data:/app/data \
            -e JAVA_OPTS="${JVM_OPTS}" \
            --restart=unless-stopped \
            ${APP_NAME}:latest
EOF
    
    log_info "容器启动完成"
}

# 验证服务
verify_service() {
    log_info "验证服务状态..."
    
    sleep 5
    
    # 检查容器状态
    CONTAINER_STATUS=$(ssh ${SERVER_USER}@${SERVER_IP} "docker ps --filter name=${APP_NAME} --format '{{.Status}}'")
    
    if [[ "${CONTAINER_STATUS}" == *"Up"* ]]; then
        log_info "容器运行状态: ${CONTAINER_STATUS}"
    else
        log_error "容器运行异常"
        ssh ${SERVER_USER}@${SERVER_IP} "docker logs --tail 50 ${APP_NAME}"
        exit 1
    fi
    
    # 检查服务响应
    HTTP_CODE=$(ssh ${SERVER_USER}@${SERVER_IP} "curl -s -o /dev/null -w '%{http_code}' http://localhost:${APP_PORT}/")
    
    if [ "${HTTP_CODE}" == "200" ]; then
        log_info "服务响应正常 (HTTP ${HTTP_CODE})"
    else
        log_warn "服务响应异常 (HTTP ${HTTP_CODE})"
    fi
}

# 输出访问信息
print_access_info() {
    echo ""
    echo "=========================================="
    echo "部署完成！"
    echo "=========================================="
    echo "应用名称: accountingTest-app"
    echo "应用版本: ${APP_VERSION}"
    echo "访问地址: http://${SERVER_IP}:${APP_PORT}/"
    echo "=========================================="
    echo ""
    echo "常用命令:"
    echo "  查看日志: ssh ${SERVER_USER}@${SERVER_IP} 'docker logs -f ${APP_NAME}'"
    echo "  重启容器: ssh ${SERVER_USER}@${SERVER_IP} 'docker restart ${APP_NAME}'"
    echo "  停止容器: ssh ${SERVER_USER}@${SERVER_IP} 'docker stop ${APP_NAME}'"
    echo "=========================================="
}

# ==================== 主流程 ====================
main() {
    echo ""
    echo "=========================================="
    echo "  SpringBoot Docker 容器化部署"
    echo "=========================================="
    echo ""
    
    check_local_env
    maven_build
    check_server_env
    upload_files
    build_image
    run_container
    verify_service
    print_access_info
}

# 执行主流程
main "$@"
