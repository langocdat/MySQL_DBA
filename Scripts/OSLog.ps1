# OSLog_Window.ps1
# Mục tiêu:
# - Kết quả dạng CSV (để vẽ biểu đồ)
# - Thu thập CPU Idle/System/User + Memory Free/Swap Used (KB) 
# - I/O Disk %Busy
# - Chạy ngầm, dừng bằng: logman stop OSLog

$LogPath = "C:\OSLogs"
$SetName = "OSLog"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = "$LogPath\OSLog_${Hostname}_${Timestamp}.csv"

# Create the folder
if (!(Test-Path $LogPath)) { 
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

# Stop and delete old collector
logman stop "$SetName" >$null 2>&1
logman delete "$SetName" >$null 2>&1

logman create counter "$SetName" `
    -c "\Processor(_Total)\% Idle Time" `
       "\Processor(_Total)\% User Time" `
       "\Processor(_Total)\% Privileged Time" `
       "\Memory\Available KBytes" `
       "\Paging File(_Total)\% Usage" `
       "\PhysicalDisk(*)\% Disk Time" `
       "\PhysicalDisk(*)\Avg. Disk Queue Length" `
       "\PhysicalDisk(*)\Disk Transfers/sec" `
    -si 10 `
    -f csv `
    -o "$LogFile" `
    -max 0
	

logman start "$SetName"

Write-Host "OSLog started! (run nohup)" -ForegroundColor Green
Write-Host "File log: $LogFile" -ForegroundColor Cyan
Write-Host "Monitor: logman query OSLog" -ForegroundColor Yellow
Write-Host "Stop: logman stop OSLog" -ForegroundColor Red

