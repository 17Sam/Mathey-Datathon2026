#!/bin/bash
# Agent P: llama-bench a la placa (un procés pesat cada cop). Ús: placa_bench.sh <etiqueta> <args extra de llama-bench...>
# Espera que el servei de producció (8081) estigui lliure abans de cada mesura.
set -u
B=~/llama.cpp/build/bin/llama-bench
OUT=~/bench_p; mkdir -p "$OUT"
TAG="$1"; shift
MODELS="${MODELS:-Q8_0 Q6_K Q5_K_M Q4_K_M}"
THREADS="${THREADS:-4 3}"
busy() { curl -s -m 3 http://127.0.0.1:8081/slots | grep -q '"is_processing":true'; }
temp() { cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -1; }
for q in $MODELS; do
  for t in $THREADS; do
    while busy; do echo "$(date +%T) 8081 ocupat, espero" >> "$OUT/$TAG.log"; sleep 5; done
    avail=$(free -m | awk '/^Mem:/{print $7}')
    if [ "$avail" -lt 700 ]; then echo "$(date +%T) available=$avail <700, paro" >> "$OUT/$TAG.log"; exit 1; fi
    echo "$(date +%T) START $q t=$t avail=$avail temp=$(temp) $*" >> "$OUT/$TAG.log"
    "$B" -m ~/models/Qwen_Qwen3.5-0.8B-$q.gguf -t "$t" -p 256 -n 64 -r 2 -o jsonl "$@" >> "$OUT/$TAG.jsonl" 2>> "$OUT/$TAG.err"
    b=no; busy && b=yes
    echo "$(date +%T) END   $q t=$t rc=$? temp=$(temp) 8081_busy_at_end=$b" >> "$OUT/$TAG.log"
  done
done
echo "$(date +%T) DONE" >> "$OUT/$TAG.log"
