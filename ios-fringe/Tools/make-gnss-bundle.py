#!/usr/bin/env python3
"""
make-gnss-bundle.py — regenerate Fringe's bundled GNSS time-series JSON.

Downloads daily IGS20 position solutions (tenv3) from the Nevada Geodetic Lab
for a station, takes the requested window, computes weekly means referenced to
the first 30 days of the window, and writes <eventId>-<STATION>.json in the
same compact format as the other bundles:

    {"station","name","t0","source","samples":[[daysSinceT0, eastMm, northMm, upMm], ...]}

Usage:
    python3 make-gnss-bundle.py <STATION> <eventId> <stationName> <t0 YYYY-MM-DD> <t1 YYYY-MM-DD> [outDir]

Example:
    python3 make-gnss-bundle.py P307 central-valley "San Joaquin GNSS station P307, west of Corcoran" 2015-01-01 2016-09-30
"""
import datetime as dt
import json
import math
import sys
import urllib.request

URL = "https://geodesy.unr.edu/gps_timeseries/IGS20/tenv3/IGS20/{st}.tenv3"
SOURCE = "Nevada Geodetic Lab, daily IGS20 solutions (tenv3)"


def fetch(station: str):
    req = urllib.request.Request(URL.format(st=station), headers={"User-Agent": "fringe-bundler/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        rows = []
        for line in r.read().decode().splitlines():
            if line.startswith("site") or line.startswith("#"):
                continue
            c = line.split()
            if len(c) < 21:
                continue
            day = dt.datetime.strptime(c[1], "%d%b%y").date()
            rows.append((day, float(c[8]), float(c[10]), float(c[12])))  # (date, east_m, north_m, up_m)
        rows.sort()
        return rows


def bundle(rows, t0, t1):
    sel = [r for r in rows if t0 <= r[0] <= t1]
    if len(sel) < 30:
        raise SystemExit(f"only {len(sel)} solutions in window; refusing to bundle")

    # Reference: mean of the first 30 days of the window.
    d0 = sel[0][0]
    ref_idx = [i for i, r in enumerate(sel) if (r[0] - d0).days <= 30]
    ref = tuple(sum(sel[i][k] for i in ref_idx) / len(ref_idx) for k in (1, 2, 3))  # (e, n, u)

    # Weekly means (7-day buckets, gap-tolerant: each bucket averages whatever falls in it).
    buckets = {}
    for r in sel:
        w = (r[0] - d0).days // 7
        buckets.setdefault(w, []).append(r)
    samples = []
    for w in sorted(buckets):
        g = buckets[w]
        day = w * 7
        vals = [(sum(r[j] for r in g) / len(g) - ref[j - 1]) * 1000 for j in (1, 2, 3)]
        if max(abs(v) for v in vals) > 2000:  # equipment-step / coseismic jump guard
            continue
        samples.append([day] + [round(v, 1) for v in vals])
    return samples


def main():
    station, event_id, name, t0s, t1s = sys.argv[1:6]
    out_dir = sys.argv[6] if len(sys.argv) > 6 else "."
    t0, t1 = dt.date.fromisoformat(t0s), dt.date.fromisoformat(t1s)
    samples = bundle(fetch(station), t0, t1)
    out = {
        "station": station,
        "name": name,
        "t0": t0s,
        "source": SOURCE,
        "samples": samples,
    }
    path = f"{out_dir}/{event_id}-{station}.json"
    with open(path, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    up_end = samples[-1][3]
    print(f"{path}: {len(samples)} weekly samples, {samples[-1][0]/365.25:.2f} yr span, up {up_end:+.1f} mm at end")


if __name__ == "__main__":
    main()
