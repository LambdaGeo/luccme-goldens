#!/usr/bin/env bash
# ==============================================================================
# run_per_year.sh — Per-year goldens for a LuccME lab (TerraME in Docker)
#
# Runs the lab with a recorder that writes <lu>_out / <lu>_pot of every cell at
# the end of every year (see scripts/per_year_snapshot.lua), and consolidates
# the result into goldens/labs_per_year/<name>/ (csv.gz + manifest.json + log).
# The lab's own parameters are not changed, except for --max-difference.
#
# Examples:
#   ./scripts/run_per_year.sh 15                       # lab15, maxDifference 300 (original)
#   ./scripts/run_per_year.sh lab15 --max-difference 10  # variant -> lab15_md10
#   ./scripts/run_per_year.sh 01 --max-difference 1643   # variant -> lab01_md1643
#
# Needs goldens/labs/LabNN_<last year>.csv (cell ids, col, row and the
# cross-check). Variants (--max-difference) are NOT labs of the LuccME package.
# ==============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="profsergiocosta/terrame-luccme"
OUT_ROOT="$ROOT_DIR/goldens/labs_per_year"
LAB="" MD=""

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-1}"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --max-difference) MD="${2:?--max-difference needs a value}"; shift 2 ;;
        --image)          IMAGE="${2:?--image needs a value}"; shift 2 ;;
        --out)            OUT_ROOT="${2:?--out needs a value}"; shift 2 ;;
        -h|--help)        usage 0 ;;
        -*)               echo "Unknown option: $1" >&2; usage ;;
        *)                [ -z "$LAB" ] && LAB="$1" || { echo "Only one lab per run" >&2; usage; }; shift ;;
    esac
done
[ -n "$LAB" ] || usage

LAB="${LAB%.lua}"
[[ "$LAB" =~ ^[0-9]+$ ]] && LAB="$(printf 'lab%02d' "$((10#$LAB))")"
[[ "$LAB" =~ ^lab[0-9]{2}$ ]] || { echo "Invalid lab: $LAB (expected 01..21)" >&2; exit 1; }
NUM="${LAB#lab}"

SRC="$ROOT_DIR/sources/labs/$LAB.lua"
[ -f "$SRC" ] || { echo "Lab not found: $SRC" >&2; exit 1; }

shopt -s nullglob
FINALS=("$ROOT_DIR"/goldens/labs/Lab${NUM}_*.csv)
[ ${#FINALS[@]} -eq 1 ] || { echo "Expected exactly one goldens/labs/Lab${NUM}_<year>.csv, found ${#FINALS[@]}" >&2; exit 1; }

NAME="$LAB"
MD_ARGS=()
if [ -n "$MD" ]; then
    NAME="${LAB}_md${MD}"
    MD_ARGS=(--max-difference "$MD")
fi
OUT_DIR="$OUT_ROOT/$NAME"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "========================================================================"
echo " Per-year golden: $NAME  (image: $IMAGE)"
echo " Output: $OUT_DIR"
echo "========================================================================"

python3 "$ROOT_DIR/scripts/lab_per_year.py" transform "$SRC" \
    --out "$WORK_DIR/target_lab.lua" --snapshot /work/snapshot.csv "${MD_ARGS[@]}"

if ! docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$WORK_DIR":/work \
        "$IMAGE" \
        bash -c "cd /work && xvfb-run -a -s '-screen 0 1280x1024x24' /opt/terrame/bin/terrame -autoclose target_lab.lua" \
        > "$WORK_DIR/execution.log" 2>&1; then
    mkdir -p "$OUT_ROOT"
    cp "$WORK_DIR/execution.log" "$OUT_ROOT/${NAME}_err.log"
    echo "FAILED (see $OUT_ROOT/${NAME}_err.log)" >&2
    exit 1
fi

[ -s "$WORK_DIR/snapshot.csv" ] || {
    mkdir -p "$OUT_ROOT"; cp "$WORK_DIR/execution.log" "$OUT_ROOT/${NAME}_err.log"
    echo "TerraME finished but wrote no snapshot (see $OUT_ROOT/${NAME}_err.log)" >&2; exit 1
}

python3 "$ROOT_DIR/scripts/lab_per_year.py" consolidate \
    --name "$NAME" --raw "$WORK_DIR/snapshot.csv" --log "$WORK_DIR/execution.log" \
    --cells "${FINALS[0]}" --source "$SRC" --image "$IMAGE" \
    --out-dir "$OUT_DIR" "${MD_ARGS[@]}"
