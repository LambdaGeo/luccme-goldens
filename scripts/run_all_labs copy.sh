#!/usr/bin/env bash
# ==============================================================================
# run_all_labs.sh — Execute LuccME Functional Labs in Docker
#
# Examples:
#   ./scripts/run_all_labs.sh 01               # Roda somente o lab01
#   ./scripts/run_all_labs.sh lab15            # Roda somente o lab15
#   ./scripts/run_all_labs.sh                  # Roda todos os 21 labs
# ==============================================================================
set -euo pipefail

TARGET_INPUT="${1:-all}"
IMAGE="${2:-profsergiocosta/terrame-luccme}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${3:-$ROOT_DIR/goldens/labs}"
mkdir -p "$OUT_DIR"

if [[ "$TARGET_INPUT" == *"/"* || "$TARGET_INPUT" == *":"* ]]; then
    IMAGE="$TARGET_INPUT"
    TARGET_INPUT="all"
fi

if [ -z "$TARGET_INPUT" ] || [ "$TARGET_INPUT" = "all" ]; then
    LAB_FILES=("$ROOT_DIR"/sources/labs/lab*.lua)
else
    CLEAN_NAME="${TARGET_INPUT%.lua}"
    if [[ "$CLEAN_NAME" =~ ^[0-9]+$ ]]; then
        CLEAN_NAME=$(printf "lab%02d" "$CLEAN_NAME")
    fi
    TARGET_FILE="$ROOT_DIR/sources/labs/${CLEAN_NAME}.lua"
    if [ ! -f "$TARGET_FILE" ]; then
        echo "Erro: Lab nao encontrado: $TARGET_FILE"
        echo "Labs disponiveis: lab01 a lab21"
        exit 1
    fi
    LAB_FILES=("$TARGET_FILE")
fi

echo "========================================================================"
echo " Running LuccME 3.1 Functional Labs in Docker ($IMAGE)"
echo " Selected: ${TARGET_INPUT}"
echo " Output directory: $OUT_DIR"
echo "========================================================================"

FAILED_LABS=()
SUCCESS_LABS=()

for lab_file in "${LAB_FILES[@]}"; do
    lab_name="$(basename "$lab_file" .lua)"
    echo -n "==> Running $lab_name... "
    
    WORK_DIR="$(mktemp -d)"
    
    # 1. Converte o lab para standalone, importa gis e luccme e preserva os shapefiles
    python3 -c "
import re

with open('$lab_file', 'r', encoding='utf-8') as f:
    code = f.read()

header = '''
import(\"gis\")
import(\"luccme\")

local unitTest = { assertSnapshot = function(self, m, n) print(\"Snapshot: \" .. tostring(n)) end }
'''

code = re.sub(r'return\s*\{\s*\w+\s*=\s*function\s*\(\s*unitTest\s*\)', header.strip(), code, count=1)
code = re.sub(r'\bend\s*,\s*\}\s*$', '', code.strip())

lines = []
skip = False
for line in code.splitlines():
    # Nao silenciar o print para podermos ver o log da simulacao
    if 'print = function' in line and 'end' in line:
        lines.append('-- ' + line)
        continue
    # Preservar shapefiles gerados comentando exclusao
    if 'filePath(' in line and '.shp' in line and 'projFile' in line:
        lines.append('-- [PRESERVE GOLDEN] ' + line)
        skip = True
        continue
    if skip:
        lines.append('-- [PRESERVE GOLDEN] ' + line)
        if 'end' in line:
            skip = False
        continue
    lines.append(line)

with open('$WORK_DIR/target_lab.lua', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')
"

    # 2. Executa via xvfb-run (sem exec) e copia estritamente shapefiles gerados (ignora cs* de entrada)
    if docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$WORK_DIR":/work \
        "$IMAGE" \
        bash -c "
            xvfb-run -a -s '-screen 0 1280x1024x24' /opt/terrame/bin/terrame -autoclose target_lab.lua
            find /opt/terrame/bin/packages/luccme/ /work/ -type f \( -iname '*.shp' -o -iname '*.dbf' -o -iname '*.shx' \) -not -iname 'cs*' -exec cp -v {} /work/ \; 2>/dev/null || true
        " > "$WORK_DIR/execution.log" 2>&1; then
        
        echo "OK"
        SUCCESS_LABS+=("$lab_name")
        
        # 3. Coleta os shapefiles gerados no WORK_DIR e converte para CSV
        find "$WORK_DIR" -maxdepth 1 -type f -iname "*.shp" -not -iname "cs*" | while read -r shp; do
            base="$(basename "$shp" .shp)"
            python3 "$ROOT_DIR/scripts/export_reference.py" "$shp" --out "$OUT_DIR/${base}.csv" 2>/dev/null || true
            cp "$shp" "$OUT_DIR/" 2>/dev/null || true
            cp "${shp%.shp}.dbf" "$OUT_DIR/" 2>/dev/null || true
            cp "${shp%.shp}.shx" "$OUT_DIR/" 2>/dev/null || true
            echo "    -> Captured golden output: $base"
        done
        
        cp "$WORK_DIR/execution.log" "$OUT_DIR/${lab_name}.log"
    else
        echo "FAILED (see $OUT_DIR/${lab_name}_err.log)"
        FAILED_LABS+=("$lab_name")
        cp "$WORK_DIR/execution.log" "$OUT_DIR/${lab_name}_err.log"
    fi
    
    rm -rf "$WORK_DIR"
done

echo "========================================================================"
echo " Execution Summary:"
echo " Successful: ${#SUCCESS_LABS[@]} / ${#LAB_FILES[@]}"
if [ ${#FAILED_LABS[@]} -gt 0 ]; then
    echo " Failed: ${FAILED_LABS[*]}"
    exit 1
else
    echo " Completed successfully!"
fi