@echo off
chcp 936 >nul
title GitHub hosts 一键更新
setlocal EnableExtensions

rem ============ 1. 检查管理员权限 ============
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [*] 需要管理员权限，正在请求提权，请在弹出的窗口里点“是”
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
set "BLOCK=%TEMP%\gh-hosts-block.txt"
set "NEW=%TEMP%\gh-hosts-new.txt"
set "SRC=https://raw.hellogithub.com/hosts"
set "BAK=%~dp0hosts-backup.bak"

echo ============================================================
echo   GitHub hosts 一键更新
echo   数据源 GitHub520
echo ============================================================
echo.

rem ============ 2. 下载最新 IP 列表 ============
echo [1/4] 正在下载最新 IP 列表
del /q "%BLOCK%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{Invoke-WebRequest -Uri '%SRC%' -OutFile '%BLOCK%' -TimeoutSec 30 -UseBasicParsing}catch{exit 1}"
if errorlevel 1 goto download_fail
if not exist "%BLOCK%" goto download_fail
powershell -NoProfile -Command "if(-not (Select-String -LiteralPath '%BLOCK%' -Pattern 'GitHub520 Host Start' -SimpleMatch -Quiet)){exit 1}"
if errorlevel 1 goto download_fail
echo       下载成功

rem ============ 3. 备份当前 hosts ============
echo [2/4] 备份当前 hosts 到 hosts-backup.bak
copy /y "%HOSTS%" "%BAK%" >nul
if errorlevel 1 (
    echo       [x] 备份失败，已中止，未修改 hosts
    echo.
    pause
    exit /b 1
)
echo       备份完成

rem ============ 4. 替换 GitHub520 配置段 ============
echo [3/4] 正在替换 GitHub520 配置段
powershell -NoProfile -ExecutionPolicy Bypass -Command "$e=([char]13).ToString()+([char]10).ToString();$b=((Get-Content -LiteralPath '%BLOCK%') -join $e).Trim();$c=Get-Content -LiteralPath '%HOSTS%' -Raw;$c=[regex]::Replace($c,'(?s)[ \t]*# GitHub520 Host Start.*?# GitHub520 Host End[^\r\n]*','');$c=[regex]::Replace($c,'(?m)^\\r\\n[ \t]*(\r?\n)','');$c=$c.TrimEnd()+$e+$e+$b+$e;[IO.File]::WriteAllText('%NEW%',$c,(New-Object Text.ASCIIEncoding));if((Get-Item '%NEW%').Length -lt 800){exit 1};if((@(Get-Content -LiteralPath '%NEW%').Count) -lt 30){exit 1}"
if errorlevel 1 goto merge_fail
copy /y "%NEW%" "%HOSTS%" >nul
if errorlevel 1 goto merge_fail
echo       写入完成，当前大小
powershell -NoProfile -Command "(Get-Item '%HOSTS%').Length.ToString() + ' 字节'"

rem ============ 5. 刷新 DNS 并验证 ============
echo [4/4] 刷新 DNS 缓存
ipconfig /flushdns >nul
powershell -NoProfile -Command "[Net.Dns]::GetHostAddresses('github.com') | Where-Object {$_.AddressFamily -eq 'InterNetwork'} | ForEach-Object {$_.IPAddressToString}" > "%TEMP%\gh-verify.txt" 2>nul
echo.
echo       github.com 现在解析到
type "%TEMP%\gh-verify.txt"
del /q "%TEMP%\gh-verify.txt" >nul 2>&1

echo.
echo ============================================================
echo   更新完成
echo   备份文件 hosts-backup.bak 与本脚本放在同一目录
echo ============================================================
echo.
pause
exit /b 0

:download_fail
echo       [x] 下载失败，请检查网络后重试
echo           也可以手动打开 https://raw.hellogithub.com/hosts
echo       hosts 没有被修改
echo.
pause
exit /b 1

:merge_fail
echo       [x] 写入失败，正在从备份还原
copy /y "%BAK%" "%HOSTS%" >nul
echo           已尝试还原，请检查 hosts 文件
echo.
pause
exit /b 1
