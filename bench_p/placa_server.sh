#!/bin/bash
# Agent P: servidor de proves al port 8091 (mai dos alhora). Ús: placa_server.sh <nom> <quant> <checkpoints> [args extra...]
set -u
NAME="$1"; Q="$2"; CK="$3"; shift 3
OUT=~/bench_p; mkdir -p "$OUT"
if pgrep -f "port 8091" >/dev/null; then echo "ja hi ha un servidor al 8091"; exit 1; fi
avail=$(free -m | awk '/^Mem:/{print $7}')
if [ "$avail" -lt 700 ]; then echo "available=$avail <700"; exit 1; fi
setsid nohup ~/llama.cpp/build/bin/llama-server -m ~/models/Qwen_Qwen3.5-0.8B-$Q.gguf --host 127.0.0.1 --port 8091 \
  --threads 4 --ctx-size 4096 --parallel 1 --cache-ram 0 --ctx-checkpoints "$CK" --jinja --reasoning off --reasoning-budget 0 \
  --alias qwen3.5-0.8b "$@" > "$OUT/server_$NAME.log" 2>&1 < /dev/null &
for i in $(seq 60); do
  sleep 1
  if curl -s -m 2 http://127.0.0.1:8091/health | grep -q '"ok"'; then echo "servidor $NAME a punt (${i}s), avail abans=$avail"; pgrep -af "port 8091" | cut -c1-300; exit 0; fi
done
echo "no arrenca"; tail -5 "$OUT/server_$NAME.log"; exit 1
