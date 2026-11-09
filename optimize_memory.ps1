# ===== Memory Optimization Script =====
# Safe, reversible memory cleanup for Windows 10/11
# Usage:
#   powershell -ExecutionPolicy Bypass -File optimize_memory.ps1            (basic)
#   powershell -ExecutionPolicy Bypass -File optimize_memory.ps1 -WithVMware (also stop VMware if idle)

param(
    [switch]$WithVMware
)

$ErrorActionPreference = 'SilentlyContinue'

function Get-FreeMemMB {
    return [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1KB, 0)
}

$before = Get-FreeMemMB
Write-Host "[*] Free memory before: $before MB"

# --- 1. Restart explorer (often leaks to 500MB+, auto-restarts instantly) ---
Write-Host "[1] Restarting explorer.exe ..."
Stop-Process -Name explorer -Force

# --- 2. Stop Phone Link / Cross-device background services ---
Write-Host "[2] Stopping PhoneExperienceHost / CrossDeviceService ..."
Stop-Process -Name PhoneExperienceHost -Force
Stop-Process -Name CrossDeviceService -Force

# --- 3. Restart TextInputHost (input method host, can bloat) ---
Write-Host "[3] Restarting TextInputHost ..."
Stop-Process -Name TextInputHost -Force

# --- 4. Optional: stop VMware if not needed ---
if ($WithVMware) {
    Write-Host "[4] Stopping VMware ..."
    Stop-Process -Name vmware -Force
    Stop-Process -Name vmware-tray -Force
}

# --- 5. Prompt .NET to release unused memory from app pools/hosts ---
Write-Host "[5] Trimming .NET working sets ..."
[System.GC]::Collect()

Start-Sleep -Seconds 6

$after = Get-FreeMemMB
$freed = $after - $before
Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Free memory : $before MB  ->  $after MB"  -ForegroundColor Cyan
Write-Host " Freed       : $freed MB"                -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Tip: WorkBuddy itself uses ~1.9 GB across its processes."
Write-Host "     Restarting the WorkBuddy app frees the most memory."
