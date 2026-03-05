@echo off
:: Cloudflare Tunnel 一键配置脚本 (Windows)
:: 用法: setup.bat <TUNNEL_NAME> <DOMAIN> <LOCAL_PORT>
:: 示例: setup.bat web-terminal work.example.com 3000

setlocal enabledelayedexpansion

set "CF=cloudflared"
set "TUNNEL_NAME=%~1"
set "DOMAIN=%~2"
set "LOCAL_PORT=%~3"

if "%TUNNEL_NAME%"=="" (
    echo 用法: %~nx0 ^<TUNNEL_NAME^> ^<DOMAIN^> ^<LOCAL_PORT^>
    echo 示例: %~nx0 web-terminal work.example.com 3000
    exit /b 1
)
if "%DOMAIN%"=="" (
    echo 错误: 请指定域名
    exit /b 1
)
if "%LOCAL_PORT%"=="" (
    echo 错误: 请指定本地端口
    exit /b 1
)

echo ============================================
echo   Cloudflare Tunnel Setup
echo   Tunnel:  %TUNNEL_NAME%
echo   Domain:  %DOMAIN%
echo   Port:    %LOCAL_PORT%
echo ============================================
echo.

:: Step 1: Login
if not exist "%USERPROFILE%\.cloudflared\cert.pem" (
    echo [1/3] 登录 Cloudflare（将打开浏览器）...
    call %CF% tunnel login
    if errorlevel 1 (
        echo 登录失败
        pause
        exit /b 1
    )
) else (
    echo [1/3] 已登录，跳过
)

:: Step 2: Create tunnel
echo [2/3] 创建 Tunnel: %TUNNEL_NAME% ...
call %CF% tunnel create %TUNNEL_NAME%
if errorlevel 1 echo   Tunnel 可能已存在，继续

:: Step 3: Route DNS
echo [3/3] 配置 DNS: %DOMAIN% -^> %TUNNEL_NAME% ...
call %CF% tunnel route dns %TUNNEL_NAME% %DOMAIN%
if errorlevel 1 echo   DNS 路由可能已存在，继续

echo.
echo ============================================
echo   Setup 完成！
echo   请手动编辑 config.yml 添加 ingress 规则
echo   配置文件: %USERPROFILE%\.cloudflared\config.yml
echo.
echo   启动: cloudflared tunnel run %TUNNEL_NAME%
echo   PM2:  pm2 start cloudflared -- tunnel run %TUNNEL_NAME%
echo ============================================
pause
