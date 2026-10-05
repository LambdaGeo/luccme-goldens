#!/usr/bin/env python3
"""check_manifests.py — verify the per-year manifests against the files they describe.

For every goldens/labs_per_year/*/manifest.json it checks that the recorded SHA-256 of
  - the lab script (source.sha256)           matches sources/labs/<lab>.lua
  - the generator (generator.sha256)         matches scripts/lab_per_year.py
  - the recorder (generator.recorder_sha256) matches scripts/per_year_snapshot.lua
  - the golden file (file.sha256)            matches the CSV in the same folder
Exit status 1 if anything differs. A generator/recorder mismatch means the goldens were produced
by another version of the script: regenerate with `make run-labs-per-year` (Docker) so the
manifests describe the code that is in the repository.
"""
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()


bad = 0
for mf in sorted((ROOT / "goldens" / "labs_per_year").glob("*/manifest.json")):
    m = json.loads(mf.read_text())
    checks = {
        "source": (m["source"]["sha256"], ROOT / m["source"]["script"]),
        "generator": (m["generator"]["sha256"], ROOT / m["generator"]["script"]),
        "recorder": (m["generator"]["recorder_sha256"], ROOT / m["generator"]["recorder"]),
        "file": (m["file"]["sha256"], mf.parent / m["file"]["name"]),
    }
    problems = [k for k, (want, path) in checks.items() if not path.exists() or sha(path) != want]
    print(f"{'OK  ' if not problems else 'DIFF'} {mf.parent.name:<14} {', '.join(problems)}")
    bad += bool(problems)
print(f"\n{bad} manifest(s) with differences")
sys.exit(1 if bad else 0)
