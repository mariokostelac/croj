#!/usr/bin/env bash
diff_file=/croj/tmp/$(basename $2)_diff
diff -w $2 $3 > $diff_file
if [[ $? -eq 0 ]]; then
  echo "✓"
  echo "Correct"
else
  echo "×"
  echo "Wrong answer"
  cat $diff_file
fi
