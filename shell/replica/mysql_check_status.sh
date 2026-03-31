#!/bin/bash
status_file_dir="/tmp/mysql_health.status"

if test -f $status_file_dir ; then
    isup=$(cat $status_file_dir | grep -c UP)
    if [ "$isup" -gt 0 ] ; then
        echo "OK"
        exit 0
    else
	echo "FAIL"
        exit 2
    fi
else
    echo "FAIL"
    exit 2
fi
