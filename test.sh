#!/usr/bin/env bash

# go out on first error
set -e

input_pipe="/communication/runner_output"
output_pipe="/communication/tester_output"

mkfifo $output_pipe

echo 'READY' > $output_pipe
echo 'Running test loop...'
# wait for the start
read < $input_pipe
while true; do
    read in < $input_pipe
    echo $in
    echo 'OK' > $output_pipe
done

rm $output_pipe
