#!/usr/bin/env python3
"""timing_report.py — environment record and summary for TerraME timing runs.

  python3 scripts/timing_report.py env [--image IMAGE]   -> goldens/timing/environment.json
  python3 scripts/timing_report.py summarize             -> goldens/timing/timing_terrame.json

The numbers are a FROZEN MEASUREMENT: they are not reproducible bit by bit, so the SHA-256
of these files identifies one specific run, not "the" TerraME time.
"""
import argparse, csv, json, os, platform, statistics, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TIMING = ROOT / "goldens" / "timing"


def sh(cmd):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, check=True).stdout.strip()
    except Exception:
        return None


def cmd_env(args):
    TIMING.mkdir(parents=True, exist_ok=True)
    digest = sh(f"docker image inspect --format '{{{{index .RepoDigests 0}}}}' {args.image}")
    mem_kb = sh("awk '/MemTotal/ {print $2}' /proc/meminfo")
    env = {
        "measured_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "image": args.image,
        "image_digest": digest,
        "docker_version": sh("docker version --format '{{.Server.Version}}'"),
        "cpu_model": sh("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2"),
        "host_cores": os.cpu_count(),
        "host_ram_mb": round(int(mem_kb) / 1024) if mem_kb else None,
        "container_limits": {"cpus": os.environ.get("CPUS", "1"), "memory": os.environ.get("MEM", "4g")},
        "kernel": platform.release(),
        "os": sh("lsb_release -ds") or platform.platform(),
    }
    out = TIMING / "environment.json"
    out.write_text(json.dumps(env, indent=2) + "\n")
    print(f"wrote {out}")


def cmd_summarize(_):
    raw = TIMING / "raw"
    summary = {"engine": "TerraME 2.0.1 (cl:fill{})", "warmup": "rep 0 excluded", "datasets": {}}
    for f in sorted(raw.glob("*_terrame_timing.csv")):
        rows = [r for r in csv.DictReader(f.open()) if int(r["rep"]) > 0]
        if not rows:
            continue
        wall = [float(r["wall_s"]) for r in rows]
        rss = [int(r["max_rss_kb"]) for r in rows]
        summary["datasets"][f.name.replace("_terrame_timing.csv", "")] = {
            "reps": len(rows),
            "wall_s": {"median": statistics.median(wall), "min": min(wall), "max": max(wall)},
            "max_rss_mb": round(max(rss) / 1024, 1),
            "raw_file": f"raw/{f.name}",
        }
    out = TIMING / "timing_terrame.json"
    out.write_text(json.dumps(summary, indent=2) + "\n")
    print(f"wrote {out}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("env"); e.add_argument("--image", default="profsergiocosta/terrame-luccme"); e.set_defaults(fn=cmd_env)
    s = sub.add_parser("summarize"); s.set_defaults(fn=cmd_summarize)
    a = p.parse_args(); a.fn(a)
