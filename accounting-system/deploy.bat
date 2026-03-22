@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   SpringBoot Docker Deployment Script
echo ========================================
echo.

set SERVER_IP=49.235.161.106
set SERVER_PORT=22
set SERVER_USER=root
set TARGET_DIR=/opt/apps/memo-app
set APP_NAME=accountingTest-app
set APP_VERSION=1.0.0
set CONTAINER_PORT=10013

echo [Step 1/7] Checking local files...
if not exist "target\accounting-system-1.0.0.jar" (
    echo [ERROR] JAR file not found: target\accounting-system-1.0.0.jar
    exit /b 1
)
if not exist "Dockerfile" (
    echo [ERROR] Dockerfile not found
    exit /b 1
)
echo [OK] Local files check passed

echo.
echo [Step 2/7] Preparing deployment files...
copy /Y "target\accounting-system-1.0.0.jar" "target\kimi.jar" >nul
echo [OK] JAR file prepared as kimi.jar

echo.
echo [Step 3/7] Checking SSH connection...
echo Testing SSH connection to %SERVER_USER%@%SERVER_IP%:%SERVER_PORT%
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p %SERVER_PORT% %SERVER_USER%@%SERVER_IP% "echo SSH_OK" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] SSH connection failed
    echo Please ensure SSH key authentication is configured:
    echo   ssh-copy-id -p %SERVER_PORT% %SERVER_USER%@%SERVER_IP%
    exit /b 1
)
echo [OK] SSH connection successful

echo.
echo [Step 4/7] Checking server environment...
ssh -o StrictHostKeyChecking=no -p %SERVER_PORT% %SERVER_USER%@%SERVER_IP% "command -v docker && mkdir -p %TARGET_DIR% && echo ENV_OK" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Server environment check failed
    echo Please ensure Docker is installed on the server
    exit /b 1
)
echo [OK] Server environment check passed

echo.
echo [Step 5/7] Uploading files to server...
scp -P %SERVER_PORT% -o StrictHostKeyChecking=no "target\kimi.jar" %SERVER_USER%@%SERVER_IP%:%TARGET_DIR%/
if errorlevel 1 (
    echo [ERROR] Failed to upload kimi.jar
    exit /b 1
)
scp -P %SERVER_PORT% -o StrictHostKeyChecking=no "Dockerfile" %SERVER_USER%@%SERVER_IP%:%TARGET_DIR%/
if errorlevel 1 (
    echo [ERROR] Failed to upload Dockerfile
    exit /b 1
)
echo [OK] Files uploaded successfully

echo.
echo [Step 6/7] Executing remote deployment...
ssh -o StrictHostKeyChecking=no -p %SERVER_PORT% %SERVER_USER%@%SERVER_IP% "bash -s" < remote-deploy.sh
if errorlevel 1 (
    echo [ERROR] Remote deployment failed
    exit /b 1
)
echo [OK] Remote deployment completed

echo.
echo [Step 7/7] Verifying service status...
timeout /t 5 /nobreak >nul
ssh -o StrictHostKeyChecking=no -p %SERVER_PORT% %SERVER_USER%@%SERVER_IP% "docker ps --filter name=accountingTest-app-container --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
echo [OK] Service verification completed

echo.
echo ========================================
echo   Deployment Completed Successfully
echo ========================================
echo.
echo Application Information:
echo   Name:      accountingTest-app
echo   Version:   1.0.0
echo   Container: accountingTest-app-container
echo.
echo Access URLs:
echo   Homepage: http://49.235.161.106:10013
echo   API Docs: http://49.235.161.106:10013/api.html
echo.
echo Useful Commands:
echo   View logs:  ssh root@49.235.161.106 "docker logs -f accountingTest-app-container"
echo   Restart:    ssh root@49.235.161.106 "docker restart accountingTest-app-container"
echo   Stop:       ssh root@49.235.161.106 "docker stop accountingTest-app-container"
echo.
echo ========================================

endlocal
