#!/bin/bash
LOCAL_IP="10.0.1.51"
MYSQL_MASTER_IP="10.0.1.51"
MYSQL_USER="mysql_check"
MYSQL_PWD="123456"
MYSQL_PORT="3306"
CHECK_RESULT_FILE="/tmp/mysql_health.status"
LOG_FILE="/var/log/mysql_check_log/mysql_health_check.log"

# 初始化结果文件
echo "UNKNOWN" > $CHECK_RESULT_FILE

# 函数：记录日志
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# 检测MySQL进程是否存活
if [ -z $(pgrep "mysqld") ]; then
    log "Mysql not Running!"
    echo "DOWN" > $CHECK_RESULT_FILE
    exit 1
fi

# 检测MySQL端口是否可达
if ! nc -z $LOCAL_IP $MYSQL_PORT > /dev/null 2>&1; then
    log "Mysql port $MYSQL_PORT not available!"
    echo "DOWN" > $CHECK_RESULT_FILE
    exit 1
fi

# 连接数据库检测
if ! mysql -h $LOCAL_IP -u$MYSQL_USER -p$MYSQL_PWD -N -e "SELECT 1" > /dev/null 2>&1; then
    log "Mysql connection ERROR!"
    echo "DOWN" > $CHECK_RESULT_FILE
    exit 1
fi

# 区分主/从库，检测复制状态
if [ $LOCAL_IP == $MYSQL_MASTER_IP ]; then
    # 主库：检测二进制日志是否开启
    MASTER_LOG=$(mysql -h $LOCAL_IP -u$MYSQL_USER -p$MYSQL_PWD -N -e "SHOW BINARY LOG STATUS" | wc -l)
    if [ "$MASTER_LOG" -eq 0 ]; then
        log "Source Binary log not available!"
        echo "DOWN" > $CHECK_RESULT_FILE
        exit 1
    fi
else
    # 从库：检测复制线程是否正常
    REPL_IO=$(mysql -h $LOCAL_IP -u$MYSQL_USER -p$MYSQL_PWD -e "SHOW REPLICA STATUS\G" | grep 'Replica_IO_Running:' | awk '{print $2}')
    REPL_SQL=$(mysql -h $LOCAL_IP -u$MYSQL_USER -p$MYSQL_PWD -e "SHOW REPLICA STATUS\G" | grep 'Replica_SQL_Running:' | awk '{print $2}')
    if [ "$REPL_IO" != "Yes" ] || [ "$REPL_SQL" != "Yes" ]; then
        log "Replica status ERROR: IO=$REPL_IO, SQL=$REPL_SQL"
        echo "DOWN" > $CHECK_RESULT_FILE
        exit 1
    fi
fi

# 所有检测通过
log "Mysql running good."
echo "UP" > $CHECK_RESULT_FILE
exit 0
