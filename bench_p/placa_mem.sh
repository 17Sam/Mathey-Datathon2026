#!/bin/bash
# Agent P: memòria de la placa i de cada llama-server (RSS, PSS si es pot llegir).
free -m | head -2
for p in $(pgrep -f llama-server); do
  port=$(tr '\0' ' ' < /proc/$p/cmdline | grep -o -- '--port [0-9]*' | cut -d' ' -f2)
  ck=$(tr '\0' ' ' < /proc/$p/cmdline | grep -o -- '--ctx-checkpoints [0-9]*' | cut -d' ' -f2)
  rss=$(awk '/^VmRSS/{print $2}' /proc/$p/status)
  anon=$(awk '/^RssAnon/{print $2}' /proc/$p/status)
  file=$(awk '/^RssFile/{print $2}' /proc/$p/status)
  pss=$(awk '/^Pss:/{print $2}' /proc/$p/smaps_rollup 2>/dev/null)
  echo "pid=$p port=$port ck=${ck:-} RSS=$((rss/1024))MB (anon=$((anon/1024)) file=$((file/1024))) PSS=$(( ${pss:-0}/1024 ))MB"
done
