@echo off
echo ========================================
echo 个人收支记账系统 - 启动脚本
echo ========================================
echo.

if not exist "target\accounting-system-1.0.0.jar" (
    echo 正在编译项目...
    call mvnw.cmd clean package -DskipTests
    if errorlevel 1 (
        echo 编译失败，请检查环境配置
        pause
        exit /b 1
    )
)

echo 正在启动服务...
echo 启动成功后，请访问: http://localhost:8080
echo 按 Ctrl+C 可停止服务
echo.
java -jar target\accounting-system-1.0.0.jar
