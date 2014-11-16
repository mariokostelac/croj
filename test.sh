#!/usr/bin/env bash

file_pattern="*.in.*"
if [[ $1 == "dummy" ]]; then
    file_pattern="*.dummy.in.*"
fi

timelimit=$(cat /test_data/timelimit)
if [[ $timelimit == "" ]]; then
    timelimit=1
fi
for in in $(find /test_data -name "$file_pattern"); do
    out=${in/.in./.out.}
    (time -p (./croj/timeout.sh "$timelimit" bash -c "./croj/tmp/a.out < $in > /croj/tmp/last_output" )) > /croj/tmp/time 2>&1
    tle=$?
    exec_time=$(cat /croj/tmp/time | grep real | cut -d' ' -f 2)
    diffs=$(diff -w $out /croj/tmp/last_output)
    if [[ $tle -ne 0 ]]; then
        echo "TLE   ${exec_time}s  $in"
    elif [[ $diffs == "" ]]; then
        echo "OK    ${exec_time}s  $in"
    else
        echo "WA    ${exec_time}s  $in"
    fi
done
