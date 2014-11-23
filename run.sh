#!/usr/bin/env bash

set -e
################################################################################
# This is the runner process. It sends the "input correct_output output"
# parameters to the tester process, each in its own line.
# When the tester is done with checking, it returns number of lines followed by
# those lines (number of lines is not included in counting).
# First line of output is considered as AC/WA/[number of points] info.
################################################################################

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
i=0
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
  input_file=${tests[i++]}
  out=${input_file/.in./.out.}
  program_out=${input_file/.in./.pout.}
  # execute the program
  (time -p (./croj/timeout.sh "$timelimit" bash -c "./croj/tmp/bin/program < $input_file > $program_out" )) > /croj/tmp/time 2>&1
  tle=$?
  exec_time=$(cat /croj/tmp/time | grep real | cut -d' ' -f 2)
  # print the user friendly result
  if [[ $tle -ne 0 ]]; then
    echo "TLE   ${exec_time}s  $input_file"
  fi
  # send the command to test it
  echo $input_file >&2
  echo $out >&2
  echo "$program_out" >&2
  # read the response
  read num_lines
  if [[ $num_lines -lt 1 ]]; then
    res="?"
  else
    read res
    for j in `seq 2 $num_lines`; do
      read line
    done
    echo "$res  ${exec_time}s  $input_file"
  fi
done < $input_pipe 2> $output_pipe

rm $output_pipe
