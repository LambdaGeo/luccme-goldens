#!/usr/bin/env python3
"""benchmark_pins.py — export (and optionally apply) the hashes the benchmarks pin.

Writes `benchmark_pins.json`: for every tracked file under goldens/ the SHA-256, size and an
immutable raw URL at a given git ref (a tag or a commit). With --apply it rewrites
`reference_url` / `reference_sha256` (and, when goldens/timing/timing_terrame.json exists,
`timing_url` / `timing_sha256`) in the `<dataset>.compare.toml` files of a disscube-benchmark
checkout, so the hashes are never copied by hand.

Usage (after committing the goldens, and tagging if you want a tag-based URL):
  python3 scripts/benchmark_pins.py                       # ref = HEAD commit
  python3 scripts/benchmark_pins.py --ref v1.1.0 --doi 10.5281/zenodo.NNNNNNN
  python3 scripts/benchmark_pins.py --ref v1.1.0 --apply ../disscube-benchmark --dry-run
  python3 scripts/benchmark_pins.py --ref v1.1.0 --apply ../disscube-benchmark

Safety: every file is checked against `git show <ref>:<path>`; if the bytes at the ref differ
from the working tree the script stops (commit or tag the goldens first), so a pinned URL can
never point to different bytes than the pinned hash.
"""
import argparse, hashlib, json, re, subprocess, sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = "LambdaGeo/luccme-goldens"
FILL_SUFFIX = "_terrame.csv"


def git(*args, binary=False):
    r = subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True)
    if r.returncode:
        raise SystemExit(f"git {' '.join(args)}: {r.stderr.decode().strip()}")
    return r.stdout if binary else r.stdout.decode().strip()


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_pins(ref, doi, verify):
    commit = git("rev-parse", f"{ref}^{{commit}}")
    files = {}
    for rel in git("ls-files", "goldens").splitlines():
        data = (ROOT / rel).read_bytes()
        digest = sha256(data)
        if verify:
            at_ref = git("show", f"{ref}:{rel}", binary=True)
            if sha256(at_ref) != digest:
                raise SystemExit(f"{rel}: working tree differs from {ref}; commit/tag the goldens first")
        files[rel] = {
            "sha256": digest,
            "size_bytes": len(data),
            "url": f"https://raw.githubusercontent.com/{REPO}/{ref}/{rel}",
        }
    fill = {
        Path(p).name[: -len(FILL_SUFFIX)]: v
        for p, v in files.items()
        if p.startswith("goldens/fill/") and p.endswith(FILL_SUFFIX)
    }
    return {
        "repo": REPO,
        "ref": ref,
        "ref_commit": commit,
        "doi": doi,
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fill": fill,
        "timing": {p: v for p, v in files.items() if p.startswith("goldens/timing/")},
        "files": files,
    }


def apply_to_benchmark(pins, bench_dir, dry_run):
    tdir = Path(bench_dir) / "benchmarks" / "terrame_fill"
    if not tdir.is_dir():
        raise SystemExit(f"{tdir} not found (pass the root of a disscube-benchmark checkout)")
    label = f"luccme-goldens {pins['ref']}" + (f" (Zenodo {pins['doi']})" if pins["doi"] else "")
    for toml in sorted(tdir.glob("*.compare.toml")):
        text = toml.read_text()
        m = re.search(r'^name\s*=\s*"([^"]+)"', text, flags=re.M)
        name = m.group(1) if m else None
        entry = pins["fill"].get(name)
        if not entry:
            print(f"skip   {toml.name}: no golden named {name!r} in this release")
            continue
        new = re.sub(r'^(reference_url\s*=\s*)"[^"]*"[^\n]*$',
                     lambda mo: f'{mo.group(1)}"{entry["url"]}"', text, flags=re.M)
        new = re.sub(r'^(reference_sha256\s*=\s*)"[^"]*"[^\n]*$',
                     lambda mo: f'{mo.group(1)}"{entry["sha256"]}"   # {label}', new, flags=re.M)
        # frozen TerraME timing (one JSON for all datasets): add/update timing_url + timing_sha256
        t = pins["files"].get("goldens/timing/timing_terrame.json")
        if t:
            lines = (f'timing_url       = "{t["url"]}"\n'
                     f'timing_sha256    = "{t["sha256"]}"\n')
            new = re.sub(r'^timing_url\s*=.*\n^timing_sha256\s*=.*\n', "", new, flags=re.M)
            new = re.sub(r'^(reference_sha256\s*=[^\n]*\n)', lambda mo: mo.group(1) + lines, new, count=1, flags=re.M)
        if new == text:
            print(f"same   {toml.name}")
            continue
        print(f"{'would update' if dry_run else 'updated'} {toml.name}")
        if not dry_run:
            toml.write_text(new)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", help="git tag or commit for the URLs (default: HEAD commit)")
    ap.add_argument("--doi", help="Zenodo DOI of this release, recorded in the pins and in comments")
    ap.add_argument("--out", default=str(ROOT / "benchmark_pins.json"))
    ap.add_argument("--no-verify", action="store_true", help="skip the working tree vs ref byte check")
    ap.add_argument("--apply", metavar="BENCHMARK_DIR", help="rewrite compare.toml pins in a disscube-benchmark checkout")
    ap.add_argument("--dry-run", action="store_true", help="with --apply: show what would change")
    a = ap.parse_args()

    ref = a.ref or git("rev-parse", "HEAD")
    pins = build_pins(ref, a.doi, verify=not a.no_verify)
    Path(a.out).write_text(json.dumps(pins, indent=2) + "\n")
    print(f"wrote {a.out} ({len(pins['files'])} files, ref {ref})")
    for name, e in sorted(pins["fill"].items()):
        print(f"  fill/{name:<13} {e['sha256']}")
    if a.apply:
        apply_to_benchmark(pins, a.apply, a.dry_run)


if __name__ == "__main__":
    main()
