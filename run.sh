#!/usr/bin/env bash

# set -e
################################################################################
# This is the runner process. It sends the "input correct_output output"
# parameters to the tester process, each in its own line.
# When the tester is done with checking, it returns number of lines followed by
# those lines (number of lines is not included in counting).
# First line of output is considered as AC/WA/[number of points] info.
################################################################################

trap "exit" INT

if [[ $# -eq 1 ]]; then
    tests_to_run=`echo $1 | tr "," " " | sort`
    read -a tests_to_run <<< "$tests_to_run"
fi

file_pattern="*.in.*"

# check the timelimit
if [[ -f /test_data/timelimit ]]; then
  timelimit=$(cat /test_data/timelimit)
fi
if [[ $timelimit == "" ]]; then
  timelimit=1
fi

# prepare files for communication tester <-> runner
output_pipe="/communication/runner_output"
input_pipe="/communication/tester_output"
mkfifo $output_pipe

# just to be sure that the tester is running
echo "Waiting for testing container..."
while [[ ! -p $input_pipe ]]; do
  sleep 1
done

# prepare array with tests
unset tests i
while IFS= read -r -d '' file; do
  tests[i++]="$file"
done < <(find /test_data -name "$file_pattern" -print0)
tests_len=${#tests[@]}

echo "Running..."
echo "Timelimit     ${timelimit}s"
echo "--------------------------------------------------------------------------------"

log_file="/croj/tmp/status.running"

# remove the log file if it already exists
if [[ -f $log_file ]]; then
  rm $log_file
fi
touch $log_file

i=0
k=0
while true; do
  # wait for the start message
  if [[ $i -eq 0 ]]; then
    read -r
  fi
  # break if done
  if [[ $i -eq $tests_len ]]; then
    break
  fi
  # prepare name of input/output files
  input_file=${tests[i]}
  i=$(( i+1 ))
  if [[ $# -eq 1 && ${tests_to_run[k]} -ne $i ]]; then
      continue
  fi
  k=$(( k+1 ))

  out=${input_file/.in./.out.}
  program_out=/croj/tmp/$(basename ${input_file/.in./.pout.})

  echo $input_file >> $log_file

  # execute the program
  (time -p (./croj/timeout.sh "$timelimit" bash -c "./croj/tmp/bin/program < $input_file > $program_out 2>> /croj/tmp/err" )) > /croj/tmp/time 2>&1
  status=$?
  exec_time=$(cat /croj/tmp/time | grep real | cut -d' ' -f 2)

  # log the status and exec time
  echo $status >> $log_file
  echo $exec_time >> $log_file

  # print the fail status
  printf "$i: " >&2
  if [[ $status -eq 143 ]]; then
    echo "TLE   ${exec_time}s  $input_file" >&2
    echo 0 >> $log_file # 0 lines from checker
    continue
  elif [[ $status -ne 0 ]]; then
    echo "RTE   ${exec_time}s  $input_file" >&2
    echo 0 >> $log_file # 0 lines from checker
    continue
  fi

  # send the command to test it
  echo $input_file
  echo $out
  echo $program_out

  # read the response
  num_lines=0
  read num_lines
  echo $num_lines >> $log_file
  if [[ $num_lines -lt 1 ]]; then
    res="?"
  else
    read res
    echo $res >> $log_file
    for j in `seq 2 $num_lines`; do
      read line
      echo $line >> $log_file
    done
    echo "$res  ${exec_time}s  $input_file" >&2
  fi

done < $input_pipe > $output_pipe

touch /croj/tmp/status.done

rm $output_pipe
