#!/bin/ksh

#-----Declare variable for script
host=$(hostname)
os=$(uname)
fmy=$(mysql --help | grep /my.cnf | xargs ls)

if [[ "$os" == 'Linux' ]]; then
	grep='grep'
	awk='awk'
	java_check="version"
else
	grep='ggrep'
	awk='nawk'
	java_check="version"
fi

#-----Start script
echo
echo "MAKE SURE SERVER HAS KSH (KORNSHELL)*"
echo "Set variable for the process..."
echo "===============>>"
if [[ "$os" == 'Linux' ]]; then
	read -p " <> USERNAME : " user
	read -s -p " <> PASSWORD : " pass
else
	read user?" <> USERNAME : "
	read pass?" <> PASSWORD : "
fi
cnn_str="mysql -u $user -p"$pass

export PATH=$ORACLE_HOME/bin:$PATH
echo "<<==============="

#-----Get Date now
time=$(date +'%d_%m_%Y')

#-----Get pwd script
SCRIPT=$(readlink -f "$0")
pwd=$(dirname "$SCRIPT")

#-----Check connection
if
	echo "exit;" | $cnn_str 2>&1 | grep -q "MySQL"
then
	echo Connect Database SUCCESS
else
	echo Connect Database FAIL
fi

#-----Get db_name (all)
dbnames=$(
	$cnn_str -se "SELECT schema_name from INFORMATION_SCHEMA.SCHEMATA  WHERE schema_name NOT IN('information_schema', 'mysql', 'performance_schema', 'sys');"
)

#-----Get database home(data directory)
dbhome=$(
	$cnn_str -se "SELECT CONCAT(@@datadir);"
)

#-----Get alert log path
spwd=$(
	$cnn_str -se "SELECT CONCAT(@@datadir);"
)

Head() {
	#-----Choose Database
    echo "===============>>"
	echo " <> LIST DATABASE IN MYSQL  :" $dbnames " / 1: Exit"
    if [[ "$os" == 'Linux' ]]; then
	read -p " <> DATABASE NAME (Or Exit) : " dbname
    else
	read dbname?" <> DATABASE NAME (Or Exit) : "
    fi

	if [[ "$dbname" == 1 ]]; then
	echo
	#exit
	break
	else
	dbname=$dbname
	fi

    echo "<<==============="

    #-----Create folder
	echo
	echo ">>--------------------------- *** ---------------------------<<"
	echo "<<========================<<  MPS  >>========================>>"
	echo ">>--------------------------- *** ---------------------------<<"
	echo
	echo " <> OS Machine  :" $os
	echo " <> Date Time   :" $time
	echo " <> Script      :" $pwd
    echo " <> List DB     :" $dbnames
	echo " <> DB Name     :" $dbname
	echo " <> Data Dir    :" $dbhome$dbname
	echo " <> File my.cnf :" $fmy
	echo " <> OSWbb Log   :" $pwd/oswbb_log_MPS_$host
	echo
	echo "|<<=======================<<  ***  >>=======================>>|"
	echo "|                                                             |"
	echo "|                    ---------------------                    |"
	echo "|   <<===>>       << HEALTH-CHECK-DATABASE >>       <<===>>   |"
	echo "|                    ---------------------                    |"
	echo "|                                                             |"
	echo "| ==>> 1. Get Database Information.                           |"
	echo "|                                                             |"
	echo "| ==>> 2. Run OSWatcher.                                      |"
	echo "|                                                             |"
	echo "| ==>> 3. Cancel Script.                                      |"
	echo "|                                                             |"
	echo "|                                                             |"
	echo "|                                         Ver_1.2.0_VictorMPS |"
	echo "|<<========================<< *** >>========================>>|"
	echo
	if [[ "$os" == 'Linux' ]]; then
		read -p "Option: " option
	else
		read option?"Option: "
	fi
}

Body() {

#==#==Option Failed.
if [[ -z $option || $option < 1 || $option > 3 ]]; then
	echo
	echo "=> #Error! Choose again."

#==#==Option 1.(Run collect log)
elif [ $option == 1 ]; then
	echo
	echo "Processing..."
	echo

#-----database_information
file_name='database_information_'$dbname'.html'
touch $file_name

#--Header
echo "<html>
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=US-ASCII\">
<meta name=generator content=\"SQL*Plus 12.2.0\">
<TITLE>DATABASE INFORMATION</TITLE>  <STYLE TYPE='TEXT/CSS'></STYLE>
</head>
<body TEXT='#FF0000'>" >>$file_name

echo "<p>===========SOFTWARE_PART===========</p>" >>$file_name

#--Check Database Software Information
#----Check Software Information
echo "<p>+ SOFTWARE_INFORMATION</p>" >>$file_name
$cnn_str -H -se "
SELECT
	(SELECT mysql_version FROM sys.version) 'VERSION',
	CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) 'DATABASE SIZE (GB)',
	(SELECT ROUND(total_allocated/1024/1024/1024,2) FROM sys.\`x\$memory_global_total\`) 'MEMORY ALLOCATED (GB)'
FROM 
    INFORMATION_SCHEMA.TABLES;" >>$file_name

#----Check Log location
echo "<p>+ LOG_VARIABLE</p>" >>$file_name
$cnn_str -H -se "
SELECT
    VARIABLE_NAME 'LOG TYPE',
    VARIABLE_VALUE 'LOG STATUS'
FROM
    performance_schema.global_variables
WHERE
    VARIABLE_NAME IN ('log_error','binlog_error_action','general_log','general_log_file','slow_query_log','slow_query_log_file');" >>$file_name

#----Check Error Log *** (Delete thread id)
echo "<p>+ ERROR_LOG</p>" >>$file_name
$cnn_str -H -se "
SELECT
    *
FROM
    performance_schema.error_log
ORDER BY
    LOGGED DESC LIMIT 30;" >>$file_name

#----Check Top 10 Memory By Event
echo "<p>+ MEMORY_BY_EVENT</p>" >>$file_name
$cnn_str -H -se "
SELECT
	event_name 'EVENT NAME',
	high_count 'MAX COUNT',
	CAST(high_alloc/1024/1024 as decimal(10,2)) 'MAX ALLOCATE (MB)',
	CAST(high_avg_alloc/1024/1024 as decimal(10,2)) 'MAX AVG ALLOCATE (MB)'
FROM
	sys.\`x\$memory_global_by_current_bytes\`
ORDER BY
	high_avg_alloc DESC LIMIT 10;" >>$file_name

#----Check Top 10 I/O By User/Thread
echo "<p>+ I/O_BY_USER/THREAD</p>" >>$file_name
$cnn_str -H -se "
SELECT
	user 'USER/THREAD',
	thread_id 'THREAD ID',
	CAST(total_latency/1000/1000/1000 as decimal(10,2)) 'TOTAL TIME (ms)',
	CAST(min_latency/1000/1000/1000 as decimal(10,2)) 'MIN TIME (ms)',
	CAST(avg_latency/1000/1000/1000 as decimal(10,2)) 'AVG TIME (ms)',
	CAST(max_latency/1000/1000/1000 as decimal(10,2)) 'MAX TIME (ms)'
FROM
	sys.\`x\$io_by_thread_by_latency\`
ORDER BY 
	avg_latency DESC LIMIT 10;" >>$file_name

#----Check Wait Class
echo "<p>+ WAITS_CLASS</p>" >>$file_name
$cnn_str -H -se "
SELECT 
	events 'EVENTS',
	total 'TOTAL',
	CAST(total_latency/1000/1000/1000 as decimal(10,2)) 'TOTAL TIME (ms)',
	CAST(avg_latency/1000/1000/1000 as decimal(10,2)) 'AVG TIME (ms)',
	CAST(max_latency/1000/1000/1000 as decimal(10,2)) 'MAX TIME (ms)'
FROM 
	sys.\`x\$waits_global_by_latency\`
ORDER BY 
	avg_latency DESC LIMIT 10;" >>$file_name

#----Check SQL Average Running
echo "<p>+ SQL_AVG_RUNNING</p>" >>$file_name
$cnn_str -H -se "
SET @id=0;
SELECT 
	@id:=@id+1 AS 'NUM ID',
	exec_count 'TOTAL EXECUTED',
	CAST(total_latency/1000/1000/1000 as decimal(10,2)) 'TOTAL TIME (ms)',
	CAST(avg_latency/1000/1000/1000 as decimal(10,2)) 'AVG TIME (ms)',
	CAST(max_latency/1000/1000/1000 as decimal(10,2)) 'MAX TIME (ms)',
	SUBSTRING(query, 1, 50) 'SQL TEXT'
FROM 
	sys.\`x\$statement_analysis\`
ORDER BY 
	avg_latency DESC LIMIT 10;" >>$file_name

#----Check SQL Command Details
echo "<p>+ SQL_COMMAND_DETAILS</p>" >>$file_name
$cnn_str -H -se "
SET @id=0;
SELECT 
	@id:=@id+1 AS 'NUM ID',
	db 'DATABASE',
	query 'SQL TEXT'
FROM 
	sys.\`x\$statement_analysis\`
ORDER BY 
	avg_latency DESC LIMIT 10;" >>$file_name

#----Check Backup
echo "<p>+ BACKUP_DETAILS</p>" >>$file_name
$cnn_str -H -se "
SELECT
	backup_id 'BACKUP ID',
	tool_name 'TOOL NAME',
	engines 'ENGINE',
	DATE_FORMAT(start_time, '%e/%m/%Y %H:%i') 'START TIME',
	DATE_FORMAT(end_time, '%e/%m/%Y %H:%i') 'END TIME',
	TIMEDIFF(end_time,start_time) 'TIME TAKEN',
	last_error 'LAST ERROR',
	DAYNAME(start_time) 'DAY OF WEEK'
FROM
	mysql.backup_history;" >>$file_name

echo "<p>===========DATABASE_PART===========</p>" >>$file_name

#--Check Database Name & Size
echo "<p>+ DATABASE_INFORMATION</p>" >>$file_name
$cnn_str -H -se "
SELECT 
    TABLE_SCHEMA 'DATABASE NAME', 
    CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) 'DATABASE SIZE (GB)'
FROM 
    INFORMATION_SCHEMA.TABLES 
WHERE 
    TABLE_SCHEMA='$dbname';" >>$file_name

#--Check Table Information
echo "<p>+ TABLE_INFORMATION</p>" >>$file_name
$cnn_str -H -se "
SELECT 
    CONCAT(TABLE_NAME) as 'TABLE',
    ENGINE,
    CONCAT(ROUND(TABLE_ROWS/1000000,2)) 'ROWS (Mil)',
    CONCAT(ROUND(DATA_LENGTH/1024/1024,2)) 'DATA (MB)',
    CONCAT(ROUND(INDEX_LENGTH/1024/1024,2)) 'INDEX (MB)',
    CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024,2)) 'TOTAL SIZE (MB)',
    ROUND(INDEX_LENGTH/DATA_LENGTH,2) IDXFRAC,
    ROUND(DATA_FREE/(INDEX_LENGTH + DATA_LENGTH + DATA_FREE)*100) 'FRAG RATIO (%)'
FROM 
    INFORMATION_SCHEMA.TABLES
WHERE 
    TABLE_SCHEMA='$dbname'
	AND ENGINE NOT LIKE 'NULL'
ORDER BY 
    DATA_LENGTH+INDEX_LENGTH DESC;" >>$file_name

#--Check Database File System Information
echo "<p>+ DATABASE_FILE_SIZE</p>" >>$file_name
du -sBM $dbhome$dbname/* | sort -nr | $awk 'BEGIN{print("<TABLE BORDER='1'><tr><th>'FILE_NAME'</th><th>'SIZE'</th></tr>")}
{
	print("<tr><td>",$2,"</td><td>",$1,"</td></tr>")
}
END{
	print("</table><p><p>")
}' >>$file_name

#--Check Table Partition Status
echo "<p>+ TABLE_PARTITION</p>" >>$file_name
$cnn_str -H -se "
SELECT
    TABLE_NAME 'TABLE OWNER',
    PARTITION_NAME 'PARTITION NAME',
    CONCAT(ROUND(DATA_LENGTH/1024/1024,2)) 'DATA SIZE (MB)',
    CONCAT(ROUND(INDEX_LENGTH/1024/1024,2)) 'INDEX SIZE (MB)',
    CONCAT(ROUND(DATA_FREE/1024/1024,2)) 'DATA FREE (MB)'
FROM
    INFORMATION_SCHEMA.PARTITIONS
WHERE
    TABLE_SCHEMA='oggdb1'
	AND PARTITION_NAME NOT LIKE 'NULL'
UNION ALL
	SELECT 
        'NULL','NULL',0.00,0.00,0.00
    FROM 
        DUAL
ORDER BY
    ISNULL('TABLE OWNER'), 'DATA FREE (MB)' DESC;" >>$file_name

#--Check Invalid View
echo "<p>+ INVALID_VIEW</p>" >>$file_name
$cnn_str -H -se "
SELECT 
    TABLE_NAME 'TABLE NAME',
	CONCAT(ROUND((DATA_LENGTH + INDEX_LENGTH)/1024/1024,2)) 'TOTAL SIZE (MB)'

FROM 
    INFORMATION_SCHEMA.TABLES
WHERE
    TABLE_SCHEMA='$dbname'
    AND TABLE_TYPE='view'
    AND TABLE_ROWS IS NULL
    AND TABLE_COMMENT LIKE '%invalid%'
UNION ALL 
    SELECT 
        'NULL',
		0.00
    FROM 
        DUAL
ORDER BY ISNULL(TABLE_NAME) DESC;" >>$file_name

#--Check Table Statistics
echo "<p>+ TABLE_STATISTICS</p>" >>$file_name
$cnn_str -H -se "
SELECT
    TABLE_NAME 'TABLE NAME',
    UPDATE_TIME 'DATE'
FROM
    INFORMATION_SCHEMA.TABLES
WHERE
    TABLE_SCHEMA='$dbname'
    AND UPDATE_TIME IS NOT NULL
UNION ALL 
SELECT 
    'NULL',
    '01/01/2000 01:00'
FROM 
    DUAL
ORDER BY ISNULL('DATE'), 'DATE' DESC;" >>$file_name

#--Check Unused Indexes
echo "<p>+ UNUSED INDEXES</p>" >>$file_name
$cnn_str -H -se "
SELECT
    object_schema 'DATABASE',
    object_name 'TABLE NAME',
    index_name 'INDEX NAME'
FROM 
    sys.schema_unused_indexes
WHERE 
    index_name NOT LIKE 'fk_%'
    AND object_schema='$dbname'
UNION ALL
SELECT
	'NULL',
	'NULL',
	'NULL'
FROM
	DUAL;" >>$file_name

#-----OS_Command
unamestr=$(uname)
if [[ "$unamestr" == 'AIX' ]]; then
	disk_command='df -g'
else
	disk_command='df -h'
fi

#-----Disk_Usage
echo "<p>+ DISK_USAGE</p>" >>$file_name
$disk_command -P | $grep -v ^none | (
read header
echo "$header"
sort -rn -k 5 ) | $awk 'BEGIN{print("<TABLE BORDER='1'><tr><th>'FILESYSTEM'</th><th>'SIZE'</th><th>'USED'</th><th>'AVAIL'</th><th>'USE%'</th><th>'MOUNTED_ON'</th></tr>")}
{
	if ($2!="0K" && $2!="Size") {
		print("<tr><td>",$1,"</td><td>",$2,"</td><td>",$3,"</td><td>",$4,"</td><td>",$5,"</td><td>",$6,$7,"</td></tr>")
	}
}
END{
	print("</table><p><p>")
}' >>$file_name

echo "</body>" >>$file_name

sed -i 's/TABLE BORDER=1/TABLE WIDTH=90% BORDER=1/g' $file_name

#==================================================================================
#-----Get information for report file

# HA/Standalone
#rp_ha=$($cnn_str -se "SHOW SLAVE HOSTS;")

#if [[ "$rp_ha" == '' ]]; then
#	rp_ha_last='Single Instance'
#else
	#rp_ha_last='Cluster'
#fi
rp_ha=$($cnn_str -se "SHOW SLAVE HOSTS;")
grp_ha=$($cnn_str -se "SHOW PLUGINS LIKE 'group_replication';")

if [[ "$rp_ha" == '' && "$grp_ha" == *"DISABLED"* ]]; then
    rp_ha_last='Single Instance'
else
    rp_ha_last='Cluster'
fi

# OS

os1=$(uname -o)
os2=$(uname -m)
os_last="$os1 $os2"

#Hardware
if [[ "$os" == 'Linux' ]]; then
	cpu=$(lscpu | grep -E '^CPU\(s\):' | tr -dc '0-9')
	ram=$(cat /proc/meminfo | grep MemTotal | tr -dc '0-9')
	ram_last=$(expr "$ram" / 1048576)
else
	cpu=$(psrinfo -p)
	ram=$(prtconf | grep Mem | ggrep -E -o '[0-9]+')
	ram_last=$(expr "$ram" / 1024)
fi
hw_last="CPU: $cpu cores, RAM: $ram_last GB"

#Version
ver_last=$($cnn_str -se "SELECT mysql_version FROM sys.version;")

#DBsize
size=$($cnn_str -se "SELECT CONCAT(ROUND(SUM(INDEX_LENGTH+DATA_LENGTH+DATA_FREE)/1024/1024/1024,2)) FROM INFORMATION_SCHEMA.TABLES;")

size_last="$size GB"

#Backup status
bkp_last=$($cnn_str -se "SELECT last_error from mysql.backup_history order by backup_id desc limit 1;")

#Print table
echo "<p>+ REPORT DETAILS</p>" >>$file_name
echo "<table WIDTH='90%' BORDER='1'>" >>$file_name
echo "<tr><th>ITEMS</th><th>INFORMATION</th></tr>" >>$file_name
echo "<tr><td>Database Name</td><td>$dbname</td></tr>" >>$file_name
echo "<tr><td>HA/Stand Alone</td><td>$rp_ha_last</td></tr>" >>$file_name
echo "<tr><td>OS Version</td><td>$os_last</td></tr>" >>$file_name
echo "<tr><td>Hardware (CPU,RAM)</td><td>$hw_last</td></tr>" >>$file_name
echo "<tr><td>Version</td><td>$ver_last</td></tr>" >>$file_name
echo "<tr><td>DB Size</td><td>$size_last</td></tr>" >>$file_name
echo "<tr><td>Backup status</td><td>$bkp_last</td></tr></table>" >>$file_name
echo
echo "**************************"
echo "* Get Report Infor done. *"
echo "**************************"
echo
echo "End of process!"

#=========================================================================================

echo "End of process!"

#==#==Option 2 (OSWatcher).
elif [ $option == 2 ]; then
	echo
	echo "Setup OSWatcher..."
	echo

#-----Check Java Installation
if java -version 2>&1 >/dev/null | $grep "$java_check"; then
	echo "Java installed!"

	#-----Tar file oswbb840.tar
	tar -xf $pwd/oswbb840.tar -C $pwd/.

	#-----Create folder for oswbb_log
	mkdir -p $pwd/oswbb_log_MPS_$host

	#-----Start oswbb840
	cd $pwd/oswbb
	nohup ./startOSWbb.sh 300 120 None $pwd/oswbb_log_MPS_$host/ >nohup.out 2>&1 &
	echo
	echo

else
	echo "Java NOT installed!"
	echo "Prepare to Install Java!"
fi

	#==#==Option 3 (Exit).
	elif [ $option == 3 ]; then
		echo
		#exit
		break
	fi
}

#=====MainStream
Head
while :; do
	Body
	Head
done