#!/bin/bash
# Agent P: proves addicionals de llama-bench amb Q8_0 i 4 fils (un procés cada cop; espera el 8081).
set -u
B=~/llama.cpp/build/bin/llama-bench
M=~/models/Qwen_Qwen3.5-0.8B-${Q:-Q8_0}.gguf
OUT=~/bench_p; TAG=${TAG:-extra}
busy() { curl -s -m 3 http://127.0.0.1:8081/slots | grep -q '"is_processing":true'; }
run() { # run <etiqueta> <env...> -- <args...>
  local label="$1"; shift
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done; shift
  while busy; do echo "$(date +%T) 8081 ocupat, espero" >> "$OUT/$TAG.log"; sleep 5; done
  local avail=$(free -m | awk '/^Mem:/{print $7}')
  [ "$avail" -lt 700 ] && { echo "available=$avail <700, paro" >> "$OUT/$TAG.log"; exit 1; }
  echo "$(date +%T) START $label avail=$avail" >> "$OUT/$TAG.log"
  env "${envs[@]}" "$B" -m "$M" -t 4 -r 2 -o jsonl "$@" 2>> "$OUT/$TAG.err" | sed "s/^{/{\"label\": \"$label\", /" >> "$OUT/$TAG.jsonl"
  local b=no; busy && b=yes
  echo "$(date +%T) END   $label 8081_busy_at_end=$b" >> "$OUT/$TAG.log"
}
run ub-sweep X=1 -- -p 256 -n 0 -b 2048 -ub 32,64,128,256
run b128 X=1 -- -p 256 -n 64 -b 128 -ub 128
run mlock X=1 -- -p 256 -n 64 -lm mlock
run nommap X=1 -- -p 256 -n 64 -lm none
run omp-active OMP_WAIT_POLICY=active -- -p 256 -n 64
run omp-bind OMP_PROC_BIND=true OMP_WAIT_POLICY=active -- -p 256 -n 64
run fa-off X=1 -- -p 256 -n 64 -fa off
run fa-on X=1 -- -p 256 -n 64 -fa on
echo "$(date +%T) DONE" >> "$OUT/$TAG.log"
