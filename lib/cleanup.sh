#!/bin/bash
# clear previous workloads

/home/we/dust/data/sampswap/sendosc --host 127.0.0.1 --addr "/quit" --port 47113
ps -ef | grep sclang | grep -v grep | grep sampswap | awk '{print $2}' | xargs -r kill -9
ps -ef | grep scsynth | grep -v grep | grep 47112 | awk '{print $2}' | xargs -r kill -9
rm -rf /tmp/sampswap
rm -f /tmp/nrt-scready
