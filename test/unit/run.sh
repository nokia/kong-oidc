#!/bin/bash
set -e

# Run all test_*.lua files in test/unit
for f in test/unit/test_*.lua; do
  (set -x
    lua -lluacov ${f} -o TAP --failure
  )
done