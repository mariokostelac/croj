#!/usr/bin/env bash
diff -wq $2 $3 > /dev/null

if [[ $? -eq 0 ]]; then
  echo "✓"
  echo "Correct"
else
  echo "×"
  echo "Wrong answer"
fi
