#!/usr/bin/env bash
in=$1
timelimit=$2
(time -p (./croj/timeout.sh "$timelimit" bash -c "./croj/tmp/a.out < $in > /croj/tmp/last_output" )) > /croj/tmp/time 2>&1
tle=$?
exec_time=$(cat /croj/tmp/time | grep real | cut -d' ' -f 2)
if [[ $tle -ne 0 ]]; then
    echo "TLE   ${exec_time}"
else
    echo "OK    ${exec_time}"
fi
