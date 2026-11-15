#!/usr/bin/env python3
"""Agent P: taula de llama-bench a partir dels jsonl de ~/bench_p (o results/speed/bench/)."""
import json, sys, collections
for f in sys.argv[1:]:
    t = collections.OrderedDict()
    for l in open(f):
        r = json.loads(l)
        k = (r["model_filename"].split("0.8B-")[-1].replace(".gguf", ""), r["n_threads"], r["n_batch"], r["n_ubatch"])
        t.setdefault(k, {})["pp" if r["n_prompt"] else "tg"] = (r["avg_ts"], r["stddev_ts"])
    print(f"## {f}")
    print("| quant | fils | b/ub | lectura pp t/s | escriptura tg t/s |")
    print("|---|---|---|---|---|")
    for (q, th, b, ub), v in t.items():
        pp = v.get("pp", (0, 0)); tg = v.get("tg", (0, 0))
        print(f"| {q} | {th} | {b}/{ub} | {pp[0]:.2f} ± {pp[1]:.2f} | {tg[0]:.2f} ± {tg[1]:.2f} |")
