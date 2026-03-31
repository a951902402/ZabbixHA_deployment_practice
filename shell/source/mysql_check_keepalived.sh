#!/bin/bash
CHECK_RESULT_FILE="/tmp/mysql_health.status"

if [ ! -f $CHECK_RESULT_FILE ]; then
    exit 1
fi

RESULT=$(cat $CHECK_RESULT_FILE)
if [ "$RESULT" == "UP" ]; then
    exit 0
else
    exit 1
fi
