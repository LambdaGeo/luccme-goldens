#!/usr/bin/env bash
# ==============================================================================
# measure_timing.sh — Measure TerraME wall/CPU time and peak memory (fill cases)
#
# Usage:
#   ./scripts/measure_timing.sh [DATASET|all] [REPS] [IMAGE]
#
# Examples:
#   ./scripts/measure_timing.sh connectivity 5
#   ./scripts/measure_timing.sh itaituba 5 profsergiocosta/terrame-luccme@sha256:<DIGEST>
#
# Output (frozen measurement; see goldens/timing/README.md):
#   goldens/timing/raw/<dataset>_terrame_timing.csv   rep,wall_s,user_s,sys_s,max_rss_kb
#   (rep 0 is a warm-up run and is excluded from the summary)
#
# The time is measured INSIDE the container, around the terrame command only, so
# `docker run` start-up and Xvfb start-up are not counted. Same limits as the
# DisSCube side of the benchmark: --cpus=1 --memory=4g (override with CPUS/MEM).
# Requires /usr/bin/time in the image: profsergiocosta/terrame-luccme >= 0.4.2 (terrame-docker).
# ==============================================================================
set -euo pipefail

TARGET="${1:-all}"
REPS="${2:-5}"
IMAGE="${3:-profsergiocosta/terrame-luccme}"
CPUS="${CPUS:-1}"
MEM="${MEM:-4g}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/goldens/timing/raw}"
mkdir -p "$OUT_DIR"

if [ "$TARGET" = "all" ]; then
    DATASETS=(itaituba amazonia emas majority connectivity)
else
    DATASETS=("$(echo "$TARGET" | tr '[:upper:]' '[:lower:]' | sed 's/\.lua$//')")
fi

# Fail early if /usr/bin/time is missing in the image
if ! docker run --rm --entrypoint test "$IMAGE" -x /usr/bin/time; then
    echo "Error: /usr/bin/time not found in $IMAGE (use a terrame-luccme image >= 0.4.2, which includes GNU time)." >&2
    exit 1
fi

for dataset in "${DATASETS[@]}"; do
    LUA_SOURCE="$ROOT_DIR/sources/fill/$dataset.lua"
    [ -f "$LUA_SOURCE" ] || { echo "Error: $LUA_SOURCE not found" >&2; exit 1; }

    CSV="$OUT_DIR/${dataset}_terrame_timing.csv"
    echo "rep,wall_s,user_s,sys_s,max_rss_kb" > "$CSV"

    for rep in $(seq 0 "$REPS"); do
        WORK_DIR="$(mktemp -d)"
        cp "$LUA_SOURCE" "$WORK_DIR/"
        echo -n "==> $dataset rep $rep/$REPS... "

        docker run --rm --cpus="$CPUS" --memory="$MEM" \
            --user "$(id -u):$(id -g)" \
            -v "$WORK_DIR":/work -w /work \
            "$IMAGE" \
            bash -c "xvfb-run -a -s '-screen 0 1280x1024x24' \
                /usr/bin/time -f '%e,%U,%S,%M' -o /work/.time \
                /opt/terrame/bin/terrame -autoclose $dataset.lua" \
            > "$WORK_DIR/execution.log" 2>&1 \
            || { echo "FAILED (log: $WORK_DIR/execution.log)"; exit 1; }

        echo "$rep,$(tail -n 1 "$WORK_DIR/.time")" >> "$CSV"
        tail -n 1 "$CSV"
        rm -rf "$WORK_DIR"
    done
done

echo "Raw timings in $OUT_DIR. Next: python3 scripts/timing_report.py env && python3 scripts/timing_report.py summarize"
