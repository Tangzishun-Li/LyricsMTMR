#!/bin/bash
for d in /tmp/LyricsMTMR-dd-r54reg*; do
  [ -d "$d" ] && rm -rf "$d"
done
echo "done"
