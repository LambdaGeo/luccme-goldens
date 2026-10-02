#!/usr/bin/env bash
# ==============================================================================
# run_all_fill.sh — Execute TerraME GIS Fill Cases in Docker
#
# Usage:
#   ./scripts/run_all_fill.sh [DATASET_OR_ALL] [IMAGE_NAME] [OUT_DIR]
#
# Examples:
#   ./scripts/run_all_fill.sh
#   ./scripts/run_all_fill.sh itaituba
#   ./scripts/run_all_fill.sh amazonia
#   ./scripts/run_all_fill.sh emas
#
# Datasets:
#   - itaituba.lua (Itaituba/PA, 5 km, EPSG:29191)
#   - amazonia.lua (Amazonia Legal, 50 km, EPSG:29191)
#   - emas.lua (Parque Nacional das Emas, 500 m, EPSG:29192)
# ==============================================================================
set -euo pipefail

TARGET_ARG="${1:-all}"
IMAGE="${2:-profsergiocosta/terrame-luccme}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${3:-$ROOT_DIR/goldens/fill}"
mkdir -p "$OUT_DIR"

echo "========================================================================"
echo " Running TerraME 2.0.1 GIS Fill Operations in Docker ($IMAGE)"
echo " Target: $TARGET_ARG | Output directory: $OUT_DIR"
echo "========================================================================"

if [ "$TARGET_ARG" = "all" ]; then
    DATASETS=("itaituba" "amazonia" "emas")
else
    CLEAN_NAME=$(echo "$TARGET_ARG" | tr '[:upper:]' '[:lower:]' | sed 's/\.lua$//')
    DATASETS=("$CLEAN_NAME")
fi

for dataset in "${DATASETS[@]}"; do
    LUA_SOURCE="$ROOT_DIR/sources/fill/$dataset.lua"
    if [ ! -f "$LUA_SOURCE" ]; then
        echo "Error: Fill script not found: $LUA_SOURCE"
        exit 1
    fi

    echo -n "==> Running $dataset.lua... "
    WORK_DIR="$(mktemp -d)"
    cp "$LUA_SOURCE" "$WORK_DIR/"
    
    # 1. Executa via xvfb-run dentro do container e captura os shapefiles gerados
    if docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$WORK_DIR":/work \
        "$IMAGE" \
        bash -c "
            xvfb-run -a -s '-screen 0 1280x1024x24' /opt/terrame/bin/terrame -autoclose $dataset.lua
            mkdir -p /work/output_shps
            find /root/.terrame/ -name '*.shp' -exec cp {} /work/output_shps/ \; 2>/dev/null || true
            find /home -name '*.shp' -exec cp {} /work/output_shps/ \; 2>/dev/null || true
        " > "$WORK_DIR/execution.log" 2>&1; then
        
        echo "OK"

        # Localiza o shapefile gerado
        TARGET_SHP=""
        if [ -f "$WORK_DIR/$dataset.shp" ]; then
            TARGET_SHP="$WORK_DIR/$dataset.shp"
        elif [ -f "$WORK_DIR/output_shps/$dataset.shp" ]; then
            TARGET_SHP="$WORK_DIR/output_shps/$dataset.shp"
            cp "$WORK_DIR"/output_shps/"$dataset".* "$WORK_DIR/" 2>/dev/null || true
        else
            FOUND_SHP=$(find "$WORK_DIR" -name "*.shp" | head -n 1 || true)
            if [ -n "$FOUND_SHP" ]; then
                TARGET_SHP="$FOUND_SHP"
            fi
        fi

        if [ -n "$TARGET_SHP" ] && [ -f "$TARGET_SHP" ]; then
            # 2. Exporta o CSV canônico de referência
            python3 "$ROOT_DIR/scripts/export_reference.py" "$TARGET_SHP" \
                --out "$OUT_DIR/${dataset}_terrame.csv"
            
            # 3. Compacta o shapefile completo (.shp, .dbf, .shx, .prj, .cpg, .qix) em .zip
            SHP_DIR="$(dirname "$TARGET_SHP")"
            SHP_BASE="$(basename "$TARGET_SHP" .shp)"
            ZIP_TARGET="$OUT_DIR/${dataset}_terrame.zip"

            python3 -c "
import glob, os, zipfile
shp_dir = '$SHP_DIR'
shp_base = '$SHP_BASE'
zip_target = '$ZIP_TARGET'
valid_exts = {'.shp', '.dbf', '.shx', '.prj', '.cpg', '.qix'}
matching = [f for f in glob.glob(os.path.join(shp_dir, f'{shp_base}.*')) if os.path.splitext(f)[1].lower() in valid_exts]
with zipfile.ZipFile(zip_target, 'w', zipfile.ZIP_DEFLATED) as zf:
    for f in sorted(matching):
        zf.write(f, os.path.basename(f))
print(f'    -> Shapefile packaged into {os.path.basename(zip_target)}')
"
            echo "    -> Generated $OUT_DIR/${dataset}_terrame.csv and ${dataset}_terrame.zip"
        else
            echo "    [WARN] No output shapefile found for $dataset.lua. Check $WORK_DIR/execution.log"
        fi
    else
        echo "FAILED (see $OUT_DIR/${dataset}_err.log)"
        cp "$WORK_DIR/execution.log" "$OUT_DIR/${dataset}_err.log"
    fi
    
    rm -rf "$WORK_DIR"
done

echo "========================================================================"
echo " Fill Operations Complete!"