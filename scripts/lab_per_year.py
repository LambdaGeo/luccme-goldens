#!/usr/bin/env python3
"""
lab_per_year.py — per-year goldens for the LuccME labs.

The original goldens (goldens/labs/LabNN_<last year>.csv) keep only the final
year. This tool produces the state of every cell at the end of every year
(`<lu>_out` and `<lu>_pot`) without changing the simulation:

    transform    lab.lua -> standalone target_lab.lua with a per-year recorder
                 (scripts/per_year_snapshot.lua) and, optionally, a different
                 `maxDifference` (the "_mdN" variants)
    consolidate  raw snapshot + TerraME log -> <name>.csv.gz, manifest.json and
                 terrame.log in goldens/labs_per_year/<name>/
    compare      two per-year goldens, cell by cell, with a tolerance

The Docker run itself is in scripts/run_per_year.sh.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import sys
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
SNAPSHOT_LUA = HERE / "per_year_snapshot.lua"

ID_COLUMNS = ("id", "object_id_", "object_id0")
ITERATIONS_NOTE = (
    "continuous: LuccME's 'Number of iterations'; discrete: largest n in "
    "'Iteration -> n' (0 = first pass accepted); null = not reported in the log"
)
STANDALONE_HEADER = """\
import("gis")
import("luccme")

local unitTest = { assertSnapshot = function(self, m, n) print("Snapshot: " .. tostring(n)) end }
"""


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# ---------------------------------------------------------------------------
# transform
# ---------------------------------------------------------------------------
def transform_source(code: str, snapshot_path: str, max_difference: float | None = None) -> str:
    """Standalone version of a lab with the per-year recorder; raises if any
    expected pattern is missing instead of silently producing a different run."""
    code, n = re.subn(
        r"return\s*\{\s*\w+\s*=\s*function\s*\(\s*unitTest\s*\)",
        lambda _m: STANDALONE_HEADER.strip() + "\n\n" + SNAPSHOT_LUA.read_text(encoding="utf-8"),
        code,
        count=1,
    )
    if n != 1:
        raise SystemExit("lab does not start with `return { LabNN = function(unitTest)`")

    code, n = re.subn(r"\bend\s*,\s*\}\s*$", "", code.strip())
    if n != 1:
        raise SystemExit("lab does not end with `end, }`")

    # keep the log of the simulation (the labs silence print)
    code = "\n".join(
        ("-- " + line) if ("print = function" in line and "end" in line) else line
        for line in code.splitlines()
    )

    if max_difference is not None:
        value = f"{max_difference:g}"
        code, n = re.subn(r"(maxDifference\s*=\s*)[0-9.eE+-]+", lambda m: m.group(1) + value, code)
        if n != 1:
            raise SystemExit(f"expected exactly one `maxDifference =`, found {n}")

    def inject(m: re.Match) -> str:
        indent, env, model = m.group(1), m.group(2), m.group(3)
        if not re.search(rf"\blocal\s+{model}\s*=", code):
            raise SystemExit(f"model variable `{model}` not found for {env}")
        return f'{m.group(0)}\n{indent}{env}:add(perYearSnapshot({model}, "{snapshot_path}"))'

    code, n = re.subn(r"^([ \t]*)(env_(\w+)):add\(timer\)", inject, code, flags=re.M)
    if n != 1:
        raise SystemExit(f"expected exactly one `env_X:add(timer)`, found {n}")
    return code + "\n"


def cmd_transform(a: argparse.Namespace) -> None:
    code = Path(a.lab).read_text(encoding="utf-8")
    out = transform_source(code, a.snapshot, a.max_difference)
    Path(a.out).write_text(out, encoding="utf-8")
    print(f"Wrote {a.out}")


# ---------------------------------------------------------------------------
# consolidate
# ---------------------------------------------------------------------------
def parse_iterations(log: str, years: list[int]) -> dict[str, int | None]:
    """Iterations TerraME needed per year, from the execution log."""
    found: dict[int, int] = {}
    for m in re.finditer(r"Year:\s*(\d{4})\s+Iteration\s*->\s*(\d+)", log):
        y, n = int(m.group(1)), int(m.group(2))
        found[y] = max(found.get(y, 0), n)
    for m in re.finditer(r"Demand allocated correctly in (\d{4})\.?\s*Number of iterations:\s*(\d+)", log):
        found[int(m.group(1))] = int(m.group(2))
    return {str(y): found.get(y) for y in years}


def write_csv_gz(df: pd.DataFrame, path: Path) -> None:
    """Deterministic gzip (no timestamp, no file name) so the SHA-256 is stable."""
    with open(path, "wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as gz:
            gz.write(df.to_csv(index=False, float_format="%.12f", lineterminator="\n").encode())


def cmd_consolidate(a: argparse.Namespace) -> None:
    raw = pd.read_csv(a.raw)
    cells = pd.read_csv(a.cells)
    idcol = next((c for c in ID_COLUMNS if c in cells.columns), None)
    if idcol is None or not {"col", "row"} <= set(cells.columns):
        raise SystemExit(f"{a.cells}: needs an id column {ID_COLUMNS} plus col and row")
    cells = cells[[idcol, "col", "row"]].rename(columns={idcol: "id"})
    cells["id"] = cells["id"].astype(str)
    raw["id"] = raw["id"].astype(str)

    if cells["id"].duplicated().any():
        raise SystemExit("duplicated cell ids in the reference cells file")
    missing = set(raw["id"]) - set(cells["id"])
    if missing:
        raise SystemExit(
            f"{len(missing)} snapshot ids are not in {a.cells} (e.g. {sorted(missing)[:3]}); "
            "the cell id attribute does not match the shapefile's id column"
        )
    if set(cells["id"]) - set(raw["id"]):
        raise SystemExit("some cells of the reference file never appear in the snapshot")

    years = sorted(raw["year"].unique().tolist())
    per_year = raw.groupby("year")["id"].nunique()
    if (per_year != len(cells)).any():
        raise SystemExit(f"years with an incomplete cell set: {per_year[per_year != len(cells)].to_dict()}")

    df = raw.merge(cells, on="id", how="left", validate="m:1")
    value_cols = [c for c in raw.columns if c not in ("year", "id")]
    df = df[["year", "id", "col", "row"] + value_cols].sort_values(["year", "col", "row"]).reset_index(drop=True)

    nan_cols = [c for c in value_cols if df[c].isna().any()]
    if nan_cols:
        print(f"WARNING: NaN in {nan_cols} (attribute missing in the model)", file=sys.stderr)

    out_dir = Path(a.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / f"{a.name}.csv.gz"
    write_csv_gz(df, csv_path)

    log_text = Path(a.log).read_text(encoding="utf-8", errors="replace")
    (out_dir / "terrame.log").write_text(log_text, encoding="utf-8")

    overrides = {}
    if a.max_difference is not None:
        overrides["maxDifference"] = a.max_difference

    crosscheck: dict | None = None
    if not overrides:
        # last year against the canonical final-year golden, same cells
        ref = pd.read_csv(a.cells)
        ref[idcol] = ref[idcol].astype(str)
        last = df[df["year"] == years[-1]].merge(ref, left_on="id", right_on=idcol, suffixes=("", "_ref"))
        diffs = {
            c: float(np.abs(last[c] - last[c + "_ref"]).max())
            for c in value_cols
            if c + "_ref" in last.columns
        }
        crosscheck = {
            "tolerance": 1e-9,
            "file": Path(a.cells).name,
            "max_abs_diff": diffs,
            "note": "last year of the CSV compared with the canonical final-year golden",
        }

    manifest = {
        "lab": a.name.split("_md")[0],
        "name": a.name,
        "variant_of": a.name.split("_md")[0] if overrides else None,
        "overrides": overrides,
        "source": {"script": a.source, "sha256": sha256_file(Path(a.source))},
        "engine": {"image": a.image, "terrame": "2.0.1", "luccme": "3.1"},
        "generator": {
            "script": "scripts/lab_per_year.py",
            "sha256": sha256_file(Path(__file__)),
            "recorder": "scripts/per_year_snapshot.lua",
            "recorder_sha256": sha256_file(SNAPSHOT_LUA),
        },
        "status": "ok",
        "years": [years[0], years[-1]],
        "n_cells": int(len(cells)),
        "columns": value_cols,
        "file": {"name": csv_path.name, "rows": int(len(df)), "sha256": sha256_file(csv_path)},
        "crosscheck_vs_final_golden": crosscheck,
        "iterations_per_year": parse_iterations(log_text, years),
        "iterations_note": ITERATIONS_NOTE,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {csv_path} ({len(df):,} rows, years {years[0]}-{years[-1]})")
    if crosscheck:
        print("Cross-check vs final golden, max |diff|:", crosscheck["max_abs_diff"])


# ---------------------------------------------------------------------------
# compare
# ---------------------------------------------------------------------------
def cmd_compare(a: argparse.Namespace) -> None:
    new, ref = pd.read_csv(a.new), pd.read_csv(a.ref)
    for df in (new, ref):
        df["id"] = df["id"].astype(str)
    key = ["year", "id"]
    if len(new) != len(ref) or set(map(tuple, new[key].values)) != set(map(tuple, ref[key].values)):
        raise SystemExit(f"different (year, id) sets: {len(new)} vs {len(ref)} rows")
    m = new.merge(ref, on=key, suffixes=("_new", "_ref"), validate="1:1")
    cols = [c for c in new.columns if c not in key + ["col", "row"] and c in ref.columns]
    if not cols:
        raise SystemExit("no common value columns")
    worst, ok = 0.0, True
    print(f"{'column':<12} {'max|diff|':>12} {'MAE':>12}")
    for c in cols:
        d = np.abs(m[c + "_new"] - m[c + "_ref"])
        worst = max(worst, float(d.max()))
        flag = "" if d.max() <= a.tol else "  <-- over tolerance"
        ok &= d.max() <= a.tol
        print(f"{c:<12} {d.max():>12.3e} {d.mean():>12.3e}{flag}")
    if a.manifests:
        mn, mr = (json.loads(Path(p).read_text()) for p in a.manifests)
        it_new, it_ref = mn["iterations_per_year"], mr["iterations_per_year"]
        if not it_ref or not any(v is not None for v in it_ref.values()):
            print("iterations per year: reference has none recorded (skipped)")
        else:
            same = it_new == it_ref
            print("iterations per year:", "identical" if same else f"DIFFER {it_new} vs {it_ref}")
            ok &= same
    print(f"\n{'MATCH' if ok else 'MISMATCH'} (tolerance {a.tol:g}, worst {worst:.3e})")
    sys.exit(0 if ok else 1)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    t = sub.add_parser("transform")
    t.add_argument("lab")
    t.add_argument("--out", required=True)
    t.add_argument("--snapshot", required=True, help="path of the snapshot CSV as seen by TerraME")
    t.add_argument("--max-difference", type=float)
    t.set_defaults(func=cmd_transform)

    c = sub.add_parser("consolidate")
    c.add_argument("--name", required=True, help="e.g. lab15 or lab15_md10")
    c.add_argument("--raw", required=True)
    c.add_argument("--log", required=True)
    c.add_argument("--cells", required=True, help="canonical final-year golden CSV of the lab (id, col, row)")
    c.add_argument("--source", required=True, help="the lab's Lua file")
    c.add_argument("--out-dir", required=True)
    c.add_argument("--max-difference", type=float)
    c.add_argument("--image", default="profsergiocosta/terrame-luccme")
    c.set_defaults(func=cmd_consolidate)

    k = sub.add_parser("compare")
    k.add_argument("new")
    k.add_argument("ref")
    k.add_argument("--tol", type=float, default=1e-9)
    k.add_argument("--manifests", nargs=2, metavar=("NEW", "REF"))
    k.set_defaults(func=cmd_compare)

    a = p.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
