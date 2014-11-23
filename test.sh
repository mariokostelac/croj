#!/usr/bin/env bash

# go out on first error
set -ex

input_pipe="/communication/runner_output"
output_pipe="/communication/tester_output"

mkfifo $output_pipe

echo "Waiting for running container..." >&2
while [[ ! -p $input_pipe ]]; do
  sleep 1
done

echo 'START' > $output_pipe
echo 'Running test loop...' >&2
while true; do
    read input
    read output
    read program_output
    ./croj/tmp/bin/checker $input $output $program_output > /croj/tmp/checker_output
    wc -l < /croj/tmp/checker_output
    cat /croj/tmp/checker_output
done < $input_pipe > $output_pipe

rm $output_pipe
