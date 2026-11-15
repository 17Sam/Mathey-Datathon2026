#!/bin/bash
# Agent P: mostreig lleuger cada 5 s (temperatura màxima, freqüència de CPU, si el 8081 treballa, memòria disponible).
OUT=~/bench_p; mkdir -p "$OUT"
while true; do
  t=$(cat /sys/class/thermal/thermal_zone*/temp | sort -n | tail -1)
  f=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq | tr '\n' ',')
  p=$(curl -s -m 3 http://127.0.0.1:8081/slots | grep -o '"is_processing":[a-z]*' | head -1 | cut -d: -f2)
  a=$(free -m | awk '/^Mem:/{print $7}')
  echo "$(date +%T) temp=$t freq=$f prod_busy=$p avail=$a" >> "$OUT/sampler.log"
  sleep 5
done
