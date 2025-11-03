# mysql_hc_windows.ps1
# MySQL Health Check Script for Windows PowerShell
# Version: 1.2.0 - LaNgocDat

# === Configure ===
$hostName = hostname
$os = "Windows"
$mysqlHelp = mysql --help 2>$null
$fmy = if ($mysqlHelp -match 'Default options.*my\.cnf') { "my.cnf (check manually)" } else { "Not found" }

# === Fill the your username and your password ===
Write-Host "`nMAKE SURE SERVER HAS PowerShell"
Write-Host "Set variable for the process..."
Write-Host "===============>>"

$user = Read-Host " <> USERNAME "
$pass = Read-Host " <> PASSWORD " -AsSecureString
$passPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pass))

$cnn_str = "mysql -u `"$user`" -p`"$passPlain`""

# === Check connection to  MySQL ===
Write-Host "`n<<==============="
Write-Host "Checking database connection..."

$connectionTest = echo "exit;" | & mysql -u "$user" -p"$passPlain" 2>&1
if ($connectionTest -match "MySQL") {
    Write-Host "Connect Database SUCCESS" -ForegroundColor Green
} else {
    Write-Host "Connect Database FAIL" -ForegroundColor Red
    exit 1
}

# === Collect information ===
$time = Get-Date -Format "dd_MM_yyyy"
$SCRIPT = $MyInvocation.MyCommand.Path
$pwd = Split-Path $SCRIPT -Parent

# Collect list database
$dbnamesQuery = "$cnn_str -se `"SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA WHERE schema_name NOT IN('information_schema','mysql','performance_schema','sys');`""
$dbnames = & mysql -u "$user" -p"$passPlain" -se "SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA WHERE schema_name NOT IN('information_schema','mysql','performance_schema','sys');" | Where-Object { $_ }

# Collect datadir
$dbhome = & mysql -u "$user" -p"$passPlain" -se "SELECT @@datadir;"

# === Show menu ===
function Show-Menu {
    Clear-Host
    Write-Host ">>--------------------------- *** ---------------------------<<" -ForegroundColor Cyan
    Write-Host "<<========================<<  MPS  >>========================>>" -ForegroundColor Cyan
    Write-Host ">>                                               Ver 1.2 lnd <<" -ForegroundColor Cyan
	Write-Host ">>--------------------------- *** ---------------------------<<" -ForegroundColor Cyan

    # === GET LIST DATABASE ===
    $dbQuery = "SELECT schema_name FROM INFORMATION_SCHEMA.SCHEMATA WHERE schema_name NOT IN('information_schema','mysql','performance_schema','sys');"
	$rawOutput = & mysql -u "$user" -p"$passPlain" -B -s -N -e "$dbQuery" 2>$null

    # convert output to list
    $dbArray = @()
    if ($rawOutput) {
		$dbArray = @($rawOutput -split "`r?`n" | Where-Object { $_.Trim() -ne "" } | Sort-Object)
    }

    # === SHOW LIST ===
    Write-Host "===============>>" -ForegroundColor Yellow
    Write-Host " <> LIST DATABASE IN MYSQL : ($($dbArray.Count) databases)" -ForegroundColor White
    Write-Host " 0 : Exit script" -ForegroundColor Red

    for ($i = 0; $i -lt $dbArray.Count; $i++) {
        Write-Host " $($i + 1) : $($dbArray[$i])" -ForegroundColor Green
    }

    # === FILL CHOOSEN ===
    do {
        $choice = Read-Host "`n <> Enter database number ( or 0 to exit)"
        if ($choice -eq "0") {
            Write-Host "`nExiting script...`n" -ForegroundColor Yellow
            exit
        }
        elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $dbArray.Count) {
            $script:dbname = $dbArray[[int]$choice - 1]
            Write-Host "Selected database: $dbname`n" -ForegroundColor Green
            break
        }
        else {
            Write-Host "Invalid input! Please enter a number from 0 to $($dbArray.Count)." -ForegroundColor Red
        }
    } while ($true)

    Write-Host "<<===============`n" -ForegroundColor Yellow
	$data_dir = (($dbhome.TrimEnd('\','/') + '\' + $dbname) -replace '\\\\', '\')
	
	$my_cnf_paths = @(
		"$env:ProgramData\MySQL\MySQL Server 8.0\my.ini",
		"$env:ProgramData\MySQL\MySQL Server 8.0\my.cnf",
		"C:\my.ini",
		"C:\my.cnf",
		"$env:WINDIR\my.ini",
		"$env:WINDIR\my.cnf"
	)
	$fmy = "Not found"
	foreach ($path in $my_cnf_paths) {
		if (Test-Path $path) {
			$fmy = $path
			break
		}
	}

    # === MAIN MENU ===
    Write-Host " <> OS Machine  : $os"
    Write-Host " <> Date Time   : $time"
    Write-Host " <> Script      : $pwd"
    Write-Host " <> DB Name     : $dbname"
    Write-Host " <> Data Dir    : $data_dir"
    Write-Host " <> File my.cnf : $fmy"
	Write-Host " <> OSWbb Log   : $pwd\Not released`n"

    Write-Host "|<<=======================<<  ***  >>=======================>>|"
    Write-Host "|                    ---------------------                    |"
    Write-Host "|   <<===>>       << HEALTH-CHECK-DATABASE >>       <<===>>   |"
    Write-Host "|                    ---------------------                    |"
    Write-Host "|                                                             |"
    Write-Host "| ==>> 0. Cancel Script.                                      |"
    Write-Host "|                                                             |"
	Write-Host "| ==>> 1. Get Database Information.                           |"
	Write-Host "|                                                             |"
    Write-Host "| ==>> 2. Run OS log (Not released).                          |"
    Write-Host "|                                                             |"  
    Write-Host "|                                                Ver_1.2. lnd |"
    Write-Host "|<<========================<< *** >>========================>>|`n"

    $script:option = Read-Host "Option"
}



# === Main Process ===
function Invoke-Body {
    if ([string]::IsNullOrWhiteSpace($option) -or $option -notmatch '^[0-2]$') {
        Write-Host "`n=> #Error! Choose again.`n" -ForegroundColor Red
        return
    }

    # Option 1: Create report HTML
    if ($option -eq 1) {
        Write-Host "`nProcessing...`n"
		$currentTime = Get-Date -Format "yyyyMMdd_HH-mm"
        #$file_name = "database_information_$dbname.html"
		$file_name = "database_information_${dbname}_${currentTime}.html"
        $file_path = Join-Path $pwd $file_name
		
        # Create HTML file
        Set-Content -Path $file_path -Value @"
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=US-ASCII">
    <title>DATABASE INFORMATION</title>
    <style>
        table { border-collapse: collapse; width: 90%; margin: 10px 0; }
        th, td { border: 1px solid #ccc; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        p { font-weight: bold; color: #d00; }
    </style>
</head>
<body>

<div style="text-align:center; font-family:'Times New Roman', serif;">
<span style="color:gray;">==========</span>
<span style="font-weight:bold;color: #d00;font-size:20px;:20px">SOFTWARE_PART</span>
<span style="color:gray;">==========</span>
</div>
"@

        # Helper: Run query and add into HTML
        function Add-QueryResult {
            param([string]$title, [string]$query)
            Add-Content -Path $file_path -Value "<p>+ $title</p>"
            $result = & mysql -u "$user" -p"$passPlain" -H -se $query
            Add-Content -Path $file_path -Value $result
        }

        # === SOFTWARE part===
        Add-QueryResult "SOFTWARE_INFORMATION" @"
SELECT
    (SELECT mysql_version FROM sys.version) 'VERSION',
    CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) 'DATABASE SIZE (GB)',
    (SELECT ROUND(total_allocated/1024/1024/1024,2) FROM sys.x`$memory_global_total) 'MEMORY ALLOCATED (GB)'
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$dbname' GROUP BY TABLE_SCHEMA;
"@

        Add-QueryResult "LOG_VARIABLE" @"
SELECT 
    VARIABLE_NAME AS 'LOG TYPE',
    CASE 
        WHEN VARIABLE_NAME IN ('general_log', 'slow_query_log') THEN VARIABLE_VALUE
        WHEN VARIABLE_NAME = 'binlog_error_action' THEN VARIABLE_VALUE
        WHEN VARIABLE_NAME IN ('general_log_file', 'slow_query_log_file') 
            THEN CONCAT(@@datadir, VARIABLE_VALUE)
        WHEN VARIABLE_NAME = 'log_error' 
            THEN concat(@@GLOBAL.datadir, SUBSTRING(@@GLOBAL.log_error,3))
        ELSE VARIABLE_VALUE
    END AS 'FULL PATH / STATUS'
FROM performance_schema.global_variables
WHERE VARIABLE_NAME IN (
    'log_error','binlog_error_action','general_log',
    'general_log_file','slow_query_log','slow_query_log_file'
)
ORDER BY VARIABLE_NAME;
"@

        Add-QueryResult "ERROR_LOG" @"
SELECT * FROM performance_schema.error_log ORDER BY LOGGED DESC LIMIT 30;
"@

        Add-QueryResult "MEMORY_BY_EVENT" @"
SELECT event_name 'EVENT NAME',
       high_count 'MAX COUNT',
       CAST(high_alloc/1024/1024 AS DECIMAL(10,2)) 'MAX ALLOCATE (MB)',
       CAST(high_avg_alloc/1024/1024 AS DECIMAL(10,2)) 'MAX AVG ALLOCATE (MB)'
FROM sys.x`$memory_global_by_current_bytes
ORDER BY high_avg_alloc DESC LIMIT 10;
"@

        Add-QueryResult "I/O_BY_USER/THREAD" @"
SELECT user 'USER/THREAD', thread_id 'THREAD ID',
       CAST(total_latency/1000/1000/1000 AS DECIMAL(10,2)) 'TOTAL TIME (ms)',
       CAST(min_latency/1000/1000/1000 AS DECIMAL(10,2)) 'MIN TIME (ms)',
       CAST(avg_latency/1000/1000/1000 AS DECIMAL(10,2)) 'AVG TIME (ms)',
       CAST(max_latency/1000/1000/1000 AS DECIMAL(10,2)) 'MAX TIME (ms)'
FROM sys.x`$io_by_thread_by_latency
ORDER BY avg_latency DESC LIMIT 10;
"@

        Add-QueryResult "WAITS_CLASS (TOP WAIT EVENTS)" @"
SELECT events 'EVENTS', total 'TOTAL',
       CAST(total_latency/1000/1000/1000 AS DECIMAL(10,2)) 'TOTAL TIME (ms)',
       CAST(avg_latency/1000/1000/1000 AS DECIMAL(10,2)) 'AVG TIME (ms)',
       CAST(max_latency/1000/1000/1000 AS DECIMAL(10,2)) 'MAX TIME (ms)'
FROM sys.x`$waits_global_by_latency
ORDER BY avg_latency DESC LIMIT 10;
"@

        Add-QueryResult "SQL_AVG_RUNNING (TOP QUERIES)" @"
SET @id=0;
SELECT @id:=@id+1 AS 'NUM ID', exec_count 'TOTAL EXECUTED',
       CAST(total_latency/1000/1000/1000 AS DECIMAL(10,2)) 'TOTAL TIME (ms)',
       CAST(avg_latency/1000/1000/1000 AS DECIMAL(10,2)) 'AVG TIME (ms)',
       CAST(max_latency/1000/1000/1000 AS DECIMAL(10,2)) 'MAX TIME (ms)',
       SUBSTRING(query, 1, 50) 'SQL TEXT'
FROM sys.x`$statement_analysis
ORDER BY avg_latency DESC LIMIT 10;
"@

        Add-QueryResult "SQL_COMMAND_DETAILS (LISTT SQL TEXT)" @"
SET @id=0;
SELECT @id:=@id+1 AS 'NUM ID', db 'DATABASE', query 'SQL TEXT'
FROM sys.x`$statement_analysis
ORDER BY avg_latency DESC LIMIT 10;
"@

        Add-QueryResult "BACKUP_DETAILS (BACKUP STATUS)" @"
SELECT backup_id 'BACKUP ID', tool_name 'TOOL NAME', engines 'ENGINE',
       DATE_FORMAT(start_time, '%e/%m/%Y %H:%i') 'START TIME',
       DATE_FORMAT(end_time, '%e/%m/%Y %H:%i') 'END TIME',
       TIMEDIFF(end_time,start_time) 'TIME TAKEN', exit_state 'STATUS',
       last_error 'LAST ERROR', DAYNAME(start_time) 'DAY OF WEEK'
FROM mysql.backup_history;
"@

        # === DATABASE part ===
        #Add-Content -Path $file_path -Value "<p>===========DATABASE_PART===========</p>"
		Add-Content -Path $file_path -Value @"
<div style="text-align:center; font-family:'Times New Roman', serif;">
    <span style="color:gray;">==========</span>
    <span style="font-weight:bold; color:#d00; font-size:20px;">DATABASE_PART</span>
    <span style="color:gray;">==========</span>
</div>
"@

        Add-QueryResult "DATABASE_INFORMATION" @"
SELECT TABLE_SCHEMA 'DATABASE NAME',
       CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) 'DATABASE SIZE (GB)'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='$dbname'
GROUP BY TABLE_SCHEMA;
"@

        Add-QueryResult "TABLE_INFORMATION" @"
SELECT CONCAT(TABLE_NAME) AS 'TABLE', ENGINE,
       CONCAT(ROUND(TABLE_ROWS/1000000,2)) 'ROWS (Mil)',
       CONCAT(ROUND(DATA_LENGTH/1024/1024,2)) 'DATA (MB)',
       CONCAT(ROUND(INDEX_LENGTH/1024/1024,2)) 'INDEX (MB)',
       CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024,2)) 'TOTAL SIZE (MB)',
       ROUND(INDEX_LENGTH/DATA_LENGTH,2) IDXFRAC,
       ROUND(DATA_FREE/(INDEX_LENGTH + DATA_LENGTH + DATA_FREE)*100) 'FRAG RATIO (%)'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='$dbname' AND ENGINE IS NOT NULL
ORDER BY DATA_LENGTH+INDEX_LENGTH DESC;
"@

        # Database file size
        Add-Content -Path $file_path -Value "<p>+ DATAFILE_SIZE</p>"
        Add-Content -Path $file_path -Value "<table border='1'><tr><th>FILE_NAME</th><th>SIZE</th></tr>"
        if (Test-Path "$dbhome$dbname") {
            Get-ChildItem "$dbhome$dbname" -File | ForEach-Object {
                $sizeMB = [math]::Round($_.Length / 1MB, 2)
                Add-Content -Path $file_path -Value "<tr><td>$($_.FullName)</td><td>$sizeMB MB</td></tr>"
            }
        }
        Add-Content -Path $file_path -Value "</table><p><p>"
		
		# Table Partition information
		Add-QueryResult "TABLE PARTITION INFORMATION" @"
SELECT
    TABLE_NAME 'TABLE OWNER',
    PARTITION_NAME 'PARTITION NAME',
    CONCAT(ROUND(DATA_LENGTH/1024/1024,2)) 'DATA SIZE (MB)',
    CONCAT(ROUND(INDEX_LENGTH/1024/1024,2)) 'INDEX SIZE (MB)',
    CONCAT(ROUND(DATA_FREE/1024/1024,2)) 'DATA FREE (MB)'
FROM INFORMATION_SCHEMA.PARTITIONS
WHERE TABLE_SCHEMA='oggdb1' AND PARTITION_NAME NOT LIKE 'NULL'
UNION ALL
	SELECT 'NULL','NULL',0.00,0.00,0.00
    FROM DUAL ORDER BY ISNULL('TABLE OWNER'), 'DATA FREE (MB)' DESC;;
"@

		# Invalid View
		Add-QueryResult "INVALID VIEW" @"
SELECT 
    TABLE_NAME 'TABLE NAME',
	CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024,2)) 'DATA SIZE (MB)'

FROM 
    INFORMATION_SCHEMA.TABLES
WHERE
    TABLE_SCHEMA='$dbname'
    AND TABLE_TYPE='view'
    AND TABLE_ROWS IS NULL
    AND TABLE_COMMENT LIKE '%invalid%'
UNION ALL 
    SELECT 'NULL', 0.00 FROM DUAL;
"@

		# Table Statistics
		Add-QueryResult "TABLE STATISTICS" @"
SELECT
    TABLE_NAME 'TABLE NAME',
    UPDATE_TIME 'DATE'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA='$dbname' AND UPDATE_TIME IS NOT NULL
UNION ALL 
SELECT 'NULL', '01/01/2000 01:00'
FROM DUAL ORDER BY ISNULL('DATE'), 'DATE' DESC;
"@

		# Unused Indexes
		Add-QueryResult "UNUSED INDEXES" @"
SELECT
    object_schema 'DATABASE',
    object_name 'TABLE NAME',
    index_name 'INDEX NAME'
FROM sys.schema_unused_indexes
WHERE index_name NOT LIKE 'fk_%' AND object_schema='$dbname'
UNION ALL
SELECT 'NULL', 'NULL', 'NULL' FROM DUAL;
"@

		# HA/CLUSTERWARE STATUS
		$query = @"
SELECT 
    c.cluster_name AS 'Cluster Name',
    i.instance_name AS 'Instance',
    JSON_UNQUOTE(JSON_EXTRACT(i.addresses, '$.mysqlClassic')) AS 'Address',
    CASE 
        WHEN rg.member_role = 'PRIMARY' THEN 'PRIMARY'
        ELSE 'SECONDARY'
    END AS 'MemberRole',
    CASE 
        WHEN rg.member_role = 'PRIMARY' THEN 'R/W'
        ELSE 'R/O'
    END AS 'Mode',
    'applier_queue_applied' AS 'ReplicationLag', 
    'HA' AS 'Role', 
    rg.member_state AS 'Status',
    @@version AS 'version'
FROM mysql_innodb_cluster_metadata.clusters c
JOIN mysql_innodb_cluster_metadata.instances i 
  ON c.cluster_id = i.cluster_id
LEFT JOIN performance_schema.replication_group_members rg
  ON rg.member_host = SUBSTRING_INDEX(i.instance_name, ':', 1)
  AND rg.member_port = CAST(SUBSTRING_INDEX(i.instance_name, ':', -1) AS UNSIGNED)
ORDER BY i.instance_id;
"@
	$result = Add-QueryResult "HA/CLUSTERWARE STATUS" $query
	
	# try {
		# if ($null -eq $result) {
			# $result = Add-QueryResult "HA/CLUSTERWARE STATUS" $query
			# $rp_ha_last = "Single Instance"
		# }
		# else {
			# $rp_ha_last = "HA/Cluster"
		# }
	# }
	# catch {
		# Add-QueryResult "HA/CLUSTERWARE STATUS" $query
		# $rp_ha_last = "Single Instance"
	# }

        # Disk usage (Windows)
        Add-Content -Path $file_path -Value "<p>+ DISK_USAGE (STORAGE CAPACITY)</p>"
        $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, Size, FreeSpace, @{Name="Used";Expression={$_.Size - $_.FreeSpace}}
        Add-Content -Path $file_path -Value "<table border='1'><tr><th>FILESYSTEM</th><th>SIZE</th><th>USED</th><th>AVAIL</th><th>USE%</th></tr>"
        foreach ($d in $disks) {
            $usedGB = [math]::Round($d.Used / 1GB, 2)
            $sizeGB = [math]::Round($d.Size / 1GB, 2)
            $freeGB = [math]::Round($d.FreeSpace / 1GB, 2)
            $usePct = if ($d.Size -gt 0) { [math]::Round(($d.Used / $d.Size) * 100, 2) } else { 0 }
            Add-Content -Path $file_path -Value "<tr><td>$($d.DeviceID)</td><td>$sizeGB GB</td><td>$usedGB GB</td><td>$freeGB GB</td><td>$usePct%</td></tr>"
        }
        Add-Content -Path $file_path -Value "</table><p><p>"

        # === Report Summary ===
        $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum
		$cs = Get-WmiObject Win32_ComputerSystem
		$manufacturer = $cs.Manufacturer
		$model = $cs.Model

		$vmKeywords = @('Virtual', 'VMware', 'Hyper-V', 'VirtualBox', 'KVM', 'QEMU', 'Xen', 'Parallels')
		$isVM = $false

		foreach ($kw in $vmKeywords) {
			if ($manufacturer -match $kw -or $model -match $kw) {
				$isVM = $true
				break
			}
		}
		if (-not $isVM) {
			$ram = [math]::Round((Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
		} else {
			$ram = [math]::Round(($cs.TotalPhysicalMemory / 1GB), 0)
		}
        #$ram = [math]::Round((Get-WmiObject Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1GB, 0)
        $hw_last = "CPU: $cpu cores, RAM: $ram GB"

        $ver_last = & mysql -u "$user" -p"$passPlain" -se "SELECT mysql_version FROM sys.version;"
        $size = & mysql -u "$user" -p"$passPlain" -se "SELECT CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = '$dbname' GROUP BY TABLE_SCHEMA;"
        $size_last = "$size GB"
        $bkp_last = & mysql -u "$user" -p"$passPlain" -se "SELECT last_error FROM mysql.backup_history ORDER BY backup_id DESC LIMIT 1;"

        Add-Content -Path $file_path -Value "<p>+ REPORT DETAILS</p>"
        Add-Content -Path $file_path -Value "<table width='90%' border='1'><tr><th>ITEMS</th><th>INFORMATION</th></tr>"
        $report = @(
            "Database Name|$dbname",
            "HA/Stand Alone|$rp_ha_last",
            "OS Version|Windows $([System.Environment]::OSVersion.Version)",
            "Hardware (CPU,RAM)|$hw_last",
            "Version|$ver_last",
            "DB Size|$size_last",
            "Backup status|$bkp_last"
        )
        foreach ($item in $report) {
            $key, $val = $item -split '\|', 2
            Add-Content -Path $file_path -Value "<tr><td>$key</td><td>$val</td></tr>"
        }
        Add-Content -Path $file_path -Value "</table></body></html>"

        Write-Host "**************************" -ForegroundColor Green
        Write-Host "* Get Report Infor done. *" -ForegroundColor Green
        Write-Host "* File: $file_name        *" -ForegroundColor Green
        Write-Host "**************************`n" -ForegroundColor Green
		break;
    }

    # Option 2: Collect log OS
	
    elseif ($option -eq 2) {
        
	Write-Host "`nStarting OSWatcher for Windows in BACKGROUND..." -ForegroundColor Green
    $logDir = "C:\OSLogs"
    $logFile = Join-Path $logDir "monitor_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    # === GHI HEADER ===
    $header = "Timestamp,CPU_Idle%,CPU_System%,CPU_User%,Memory_Free_MB,Swap_Used%"
    Set-Content -Path $logFile -Value $header
    $pidFile = Join-Path $logDir "oswatcher.pid"
    $currentPid = $PID
    Set-Content -Path $pidFile -Value $currentPid

    Write-Host "Logging to: $logFile" -ForegroundColor Cyan
    Write-Host "PID saved to: $pidFile" -ForegroundColor Cyan
    Write-Host "To STOP: Run 'Stop-OSWatcher' or delete '$pidFile'" -ForegroundColor Yellow
    Write-Host "Returning to menu...`n"
    $jobScript = {
        param($logFile, $pidFile)
        $header = "Timestamp,CPU_Idle%,CPU_System%,CPU_User%,Memory_Free_MB,Swap_Used%"
        Set-Content -Path $logFile -Value $header

        while ($true) {
            try {
                if (-not (Test-Path $pidFile)) { break }

                $cpu = Get-Counter '\Processor(_Total)\% Idle Time', '\Processor(_Total)\% Privileged Time', '\Processor(_Total)\% User Time' -ErrorAction SilentlyContinue
                $mem = Get-Counter '\Memory\Available Bytes', '\Memory\% Committed Bytes In Use' -ErrorAction SilentlyContinue

                if ($cpu -and $mem) {
                    $cpuIdle  = [math]::Round($cpu.CounterSamples[0].CookedValue, 2)
                    $cpuSys   = [math]::Round($cpu.CounterSamples[1].CookedValue, 2)
                    $cpuUser  = [math]::Round($cpu.CounterSamples[2].CookedValue, 2)
                    $memFreeMB = [math]::Round($mem.CounterSamples[0].CookedValue / 1MB, 2)
                    $swapUsedPct = [math]::Round($mem.CounterSamples[1].CookedValue, 2)
                    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    $line = "$timestamp,$cpuIdle,$cpuSys,$cpuUser,$memFreeMB,$swapUsedPct"
                    Add-Content -Path $logFile -Value $line
                }
            }
            catch { }
            Start-Sleep -Seconds 30
        }
    }
    $global:oswJob = Start-Job -ScriptBlock $jobScript -ArgumentList $logFile, $pidFile
    Start-Sleep -Seconds 2
    Show-Menu
    }

    # Option 0: Exit
    elseif ($option -eq 0) {
        Write-Host "`nExiting...`n"
        exit
    }
}

function Stop-OSlog {
    $logDir = "C:\OSLogs"
    $pidFile = Join-Path $logDir "oswatcher.pid"

    if (Test-Path $pidFile) {
        $pid = Get-Content $pidFile
        Remove-Item $pidFile -Force
        Write-Host "OSWatcher STOPPED. PID file removed." -ForegroundColor Red

        # D?ng job n?u còn
        if ($global:oswJob) {
            Stop-Job $global:oswJob
            Remove-Job $global:oswJob
            $global:oswJob = $null
        }
    }
    else {
        Write-Host "OSlogs is not running (no PID file)." -ForegroundColor Yellow
    }
}

# === Main loop ===
Show-Menu
while ($true) {
    Invoke-Body
    Start-Sleep -Seconds 1
    Show-Menu
}