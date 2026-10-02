#!/usr/bin/env bash
# ==============================================================================
# run_all_fill.sh — Execute TerraME GIS Fill Cases in Docker
#
# Usage:
#   ./scripts/run_all_fill.sh [IMAGE_NAME] [OUT_DIR]
#
# Datasets:
#   - itaituba.lua (Itaituba/PA, 5 km, EPSG:29191)
#   - amazonia.lua (Amazonia Legal, 50 km, EPSG:29191)
#   - emas.lua (Parque Nacional das Emas, 500 m, EPSG:29192)
# ==============================================================================
set -euo pipefail

IMAGE="${1:-profsergiocosta/terrame-luccme}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${2:-$ROOT_DIR/goldens/fill}"
mkdir -p "$OUT_DIR"

echo "========================================================================"
echo " Running TerraME 2.0.1 GIS Fill Operations in Docker ($IMAGE)"
echo " Output directory: $OUT_DIR"
echo "========================================================================"

DATASETS=("itaituba" "amazonia" "emas")

for dataset in "${DATASETS[@]}"; do
    echo -n "==> Running $dataset.lua... "
    WORK_DIR="$(mktemp -d)"
    cp "$ROOT_DIR/sources/fill/$dataset.lua" "$WORK_DIR/"
    
    if docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$WORK_DIR":/work \
        "$IMAGE" \
        -autoclose "$dataset.lua" > "$WORK_DIR/execution.log" 2>&1; then
        
        echo "OK"
        if [ -f "$WORK_DIR/$dataset.shp" ]; then
            python3 "$ROOT_DIR/scripts/export_reference.py" "$WORK_DIR/$dataset.shp" \
                --out "$OUT_DIR/${dataset}_terrame.csv"
            echo "    -> Generated $OUT_DIR/${dataset}_terrame.csv"
        fi
    else
        echo "FAILED (see $OUT_DIR/${dataset}_err.log)"
        cp "$WORK_DIR/execution.log" "$OUT_DIR/${dataset}_err.log"
    fi
    
    rm -rf "$WORK_DIR"
done

echo "========================================================================"
echo " Fill Operations Complete!"
