#!/bin/bash
# This shell script grep json response from consul watch by using jq, install jq when you deploy this script to consul.
# For CentOS/RHEL system, use "yum install jq" or "dnf install jq" to install.

# Shell严格模式
set -u

# 变量区
LOG_FILE="/var/log/mysql_failover.log"
SOURCE_CHECK_ID="mysql-source"
REPLICA_CHECK_ID="mysql-replica"
SSH_PATH="/usr/bin/ssh"
MYSQL_REPLICA_ADDR="zbxdb2"
MYSQL_SWITCH_USER="root"
MYSQL_SWITCH_PASS="123456"

# 读取 Consul watch 传递的状态JSON，去除外层数组，保留每个check的对象
INPUT=$( cat | jq '.[]')

echo "========================================" >> "$LOG_FILE"
echo "$(date) consul Watch triggered" >> "$LOG_FILE"

# 判断MYSQL服务状态
SOURCE_ALIVE=$(echo "$INPUT" | jq --arg id "$SOURCE_CHECK_ID" '. | select(.CheckID == $id) | .Status == "passing"')
REPLICA_ALIVE=$(echo "$INPUT" | jq --arg id "$REPLICA_CHECK_ID" '. | select(.CheckID == $id) | .Status == "passing"')

echo "SOURCE_ALIVE: $SOURCE_ALIVE, REPLICA_ALIVE: $REPLICA_ALIVE" >> "$LOG_FILE"

# 主库DOWN做切换动作
if [ "$SOURCE_ALIVE" = "false" ] && [ "$REPLICA_ALIVE" = "true" ]; then
  echo "-------  Source Database FAIL detected, Ensure all Replica SQL Transcation completed first  -------"  >> "$LOG_FILE"
  # 是不是应该有个步骤检测Source是不是真的DOWN了，避免误报？
  REPLICA_STATUS_NOW=$( $SSH_PATH $MYSQL_REPLICA_ADDR "
    mysql -u$MYSQL_SWITCH_USER -p$MYSQL_SWITCH_PASS -e '
      SHOW REPLICA STATUS\G;
    '
  " | grep "Replica_SQL_Running_State:" | awk -F : '{print $2}' )
  if echo "$REPLICA_STATUS_NOW" | grep -q "has read all relay log" || echo "$REPLICA_STATUS_NOW" | grep -q "waiting for more updates"; then
    echo "-------  Replica seems good, switching to Replica  -------"  >> "$LOG_FILE"
    $SSH_PATH $MYSQL_REPLICA_ADDR "
      mysql -u$MYSQL_SWITCH_USER -p$MYSQL_SWITCH_PASS -e '
        STOP REPLICA;
        RESET BINARY LOG AND GTIDS;
        SET GLOBAL read_only=OFF;
        SET GLOBAL super_read_only=OFF;
      '
    "
    echo "Switching job finish. New Source: $MYSQL_REPLICA_ADDR" >> "$LOG_FILE"
    # 这里可以添加一些通知机制
    exit 0
  else
    echo "Replica remains unfinished transaction, aborting switch." >> "$LOG_FILE"
    # 发送告警至监控平台
    exit 1
  fi
fi
