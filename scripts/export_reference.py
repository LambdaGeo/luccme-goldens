#!/usr/bin/env python3
"""
export_reference.py — Standardize shapefiles written by TerraME into reference CSVs.

Usage:
    export_reference.py input.shp [--epsg EPSG_CODE] --out reference.csv
    export_reference.py --diff new.csv reference.csv
"""
import argparse
import sys
import geopandas as gpd
import numpy as np
import pandas as pd


def export(shp: str, epsg: int, out: str) -> None:
    g = gpd.read_file(shp)
    if epsg:
        g = g.set_crs(epsg, allow_override=True)
    c = g.geometry.centroid
    df = g.drop(columns="geometry").assign(cx=c.x.round(3), cy=c.y.round(3))
    lead = [k for k in ("id", "object_id_", "object_id0", "row", "col", "cx", "cy") if k in df.columns]
    df = df[lead + [k for k in df.columns if k not in lead]]
    if "row" in df.columns and "col" in df.columns:
        df = df.sort_values(["row", "col"])
    df.to_csv(out, index=False, float_format="%.10g")
    print(f"Exported {out} ({len(df)} rows, {len(df.columns)} columns)")


def diff(new: str, ref: str, rtol: float = 1e-6) -> bool:
    a, b = pd.read_csv(new), pd.read_csv(ref)
    if set(a.columns) != set(b.columns) or len(a) != len(b):
        print(f"Structure mismatch: len(new)={len(a)}, len(ref)={len(b)}")
        return False
    a, b = a[list(b.columns)], b
    num = a.select_dtypes("number").columns
    bad = [k for k in num if not np.allclose(a[k], b[k], rtol=rtol, atol=1e-6, equal_nan=True)]
    if bad:
        print("Differing columns:", ", ".join(bad))
        return False
    print("Files match within numerical tolerance!")
    return True


if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Export shapefiles to reference CSVs")
    p.add_argument("shp", nargs="?", help="Input shapefile path")
    p.add_argument("--epsg", type=int, help="Override EPSG CRS")
    p.add_argument("--out", help="Output CSV path")
    p.add_argument("--diff", nargs=2, metavar=("NEW", "REF"), help="Compare two CSVs")
    a = p.parse_args()
    if a.diff:
        sys.exit(0 if diff(*a.diff) else 1)
    if not a.shp or not a.out:
        p.print_help()
        sys.exit(1)
    export(a.shp, a.epsg, a.out)
