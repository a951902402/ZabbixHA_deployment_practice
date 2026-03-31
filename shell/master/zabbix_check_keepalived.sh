#!/bin/bash
ZABBIX_SERVER_PORT=10051
PORT_LISTS="netstat -tnlp | grep $ZABBIX_SERVER_PORT | wc -l"

if [ "$PORT_LISTS" -gt 0 ]; then
    exit 0
else
    exit 1
fi
