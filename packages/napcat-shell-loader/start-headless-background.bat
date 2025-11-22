@echo off
REM NapCat Headless Background Mode Launcher
REM 后台运行模式 - 不显示窗口

REM 设置代码页为UTF-8
chcp 65001 >nul

echo Starting NapCat in background (headless) mode...

REM 获取脚本所在目录
set SCRIPT_DIR=%~dp0

REM 从注册表自动获取 QQ 安装路径
for /f "tokens=2*" %%a in ('reg query "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\QQ" /v "UninstallString" 2^>nul') do (
    set "RetString=%%~b"
)

if not defined RetString (
    echo [ERROR] Cannot find QQ installation path from registry
    pause
    exit /b 1
)

REM 提取 QQ 安装目录
for %%a in ("%RetString%") do (
    set "QQInstallDir=%%~dpa"
)

REM 查找 QQ 版本目录
set "VersionsDir=%QQInstallDir%versions"
set "SelectedVersion="
if exist "%VersionsDir%" (
    for /f "delims=" %%d in ('dir /b /ad /o-d "%VersionsDir%" 2^>nul') do (
        if not defined SelectedVersion set "SelectedVersion=%%d"
    )
)

REM 设置 QQ 路径
if defined SelectedVersion (
    set "QQResPath=%VersionsDir%\%SelectedVersion%\resources\app"
) else (
    set "QQResPath=%QQInstallDir%resources\app"
)

set NAPCAT_QQ_PACKAGE_INFO_PATH=%QQResPath%\package.json
set NAPCAT_QQ_VERSION_CONFIG_PATH=%VersionsDir%\%SelectedVersion%\config.json
set NAPCAT_WRAPPER_PATH=%QQResPath%\wrapper.node

REM 使用 start /B 在后台启动 (不创建新窗口)
start /B "" cmd /c "cd /d "%SCRIPT_DIR%" && node napcat.mjs --headless > logs\napcat-headless.log 2>&1"

echo NapCat has been started in background.
echo Check logs\napcat-headless.log for output.
timeout /t 2 >nul
