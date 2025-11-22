@echo off
REM NapCat Headless Mode Launcher
REM 后台模式启动脚本 - 用于通过HTTP API集成

REM 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires Administrator privileges
    echo Attempting to restart with Administrator rights...
    powershell -Command "Start-Process 'cmd.exe' -ArgumentList '/c cd /d \"%cd%\" && \"%~f0\" %*' -Verb runAs"
    exit /b
)

REM 设置代码页为UTF-8
chcp 65001 >nul

echo ========================================
echo NapCat Headless Mode Starting...
echo ========================================

REM 获取脚本所在目录（绝对路径）
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

REM 设置 NapCat 相关路径（使用相对路径）
set NAPCAT_PATCH_PACKAGE=%SCRIPT_DIR%qqnt.json
set NAPCAT_LOAD_PATH=%SCRIPT_DIR%loadNapCat.js
set NAPCAT_INJECT_PATH=%SCRIPT_DIR%NapCatWinBootHook.dll
set NAPCAT_LAUNCHER_PATH=%SCRIPT_DIR%NapCatWinBootMain.exe

REM 查找 napcat.mjs（支持不同的构建目录结构）
set "NAPCAT_MAIN_PATH="
if exist "%SCRIPT_DIR%..\napcat-shell\dist\napcat.mjs" (
    set "NAPCAT_MAIN_PATH=%SCRIPT_DIR%..\napcat-shell\dist\napcat.mjs"
) else if exist "%SCRIPT_DIR%napcat.mjs" (
    set "NAPCAT_MAIN_PATH=%SCRIPT_DIR%napcat.mjs"
) else if exist "%SCRIPT_DIR%..\dist\napcat.mjs" (
    set "NAPCAT_MAIN_PATH=%SCRIPT_DIR%..\dist\napcat.mjs"
) else (
    echo [ERROR] Cannot find napcat.mjs
    echo Searched locations:
    echo   - %SCRIPT_DIR%..\napcat-shell\dist\napcat.mjs
    echo   - %SCRIPT_DIR%napcat.mjs
    echo   - %SCRIPT_DIR%..\dist\napcat.mjs
    pause
    exit /b 1
)

echo Found NapCat main: %NAPCAT_MAIN_PATH%

REM 从注册表自动获取 QQ 安装路径
for /f "tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ" /v "UninstallString" 2^>nul') do (
    set "RetString=%%~b"
)

if not defined RetString (
    echo [ERROR] Cannot find QQ installation path from registry
    echo Please install QQ first
    pause
    exit /b 1
)

REM 提取 QQ 安装目录和 QQ.exe 路径
for %%a in ("%RetString%") do (
    set "QQInstallDir=%%~dpa"
)
set "QQPath=%QQInstallDir%QQ.exe"

if not exist "%QQPath%" (
    echo [ERROR] QQ.exe not found at: %QQPath%
    pause
    exit /b 1
)

echo Found QQ installation: %QQPath%

REM 环境变量配置 (可选)
REM set NAPCAT_WEBUI_HOST=0.0.0.0
REM set NAPCAT_WEBUI_PORT=6099
REM set NAPCAT_WEBUI_TOKEN=your-secure-token
REM set NAPCAT_ONEBOT_PORT=3000
REM set NAPCAT_ONEBOT_HOST=127.0.0.1
REM set NAPCAT_ONEBOT_TOKEN=your-onebot-token

REM 快速登录账号 (可选)
REM set NAPCAT_QUICK_ACCOUNT=123456789

REM 转换路径为 file:// URL 格式（将反斜杠替换为正斜杠）
set NAPCAT_MAIN_PATH=%NAPCAT_MAIN_PATH:\=/%

REM 生成加载脚本（添加 --headless 参数）
echo (async () =^> {process.argv.push('--headless'); await import("file:///%NAPCAT_MAIN_PATH%")})() > "%NAPCAT_LOAD_PATH%"

echo ========================================
echo Starting QQ with NapCat injection...
echo Headless Mode: Enabled
echo ========================================

REM 使用注入方式启动 QQ
"%NAPCAT_LAUNCHER_PATH%" "%QQPath%" "%NAPCAT_INJECT_PATH%"

REM 如果程序异常退出，暂停以便查看错误
if errorlevel 1 (
    echo.
    echo ========================================
    echo NapCat exited with error code %errorlevel%
    echo ========================================
    pause
)
