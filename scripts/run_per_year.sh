#!/usr/bin/env bash
# ==============================================================================
# run_per_year.sh — Execute LuccME Per-Year Goldens in Docker
#
# Examples:
#   ./scripts/run_per_year.sh 15                           # Apenas lab15
#   ./scripts/run_per_year.sh lab15 --max-difference 10   # lab15 variante md10
#   ./scripts/run_per_year.sh all                          # Roda todos os labs
#   ./scripts/run_per_year.sh                              # Roda todos os labs
# ==============================================================================
set -euo pipefail

TARGET_INPUT="${1:-all}"
shift || true

MAX_DIFFERENCE=""
IMAGE="profsergiocosta/terrame-luccme"

# Processa parâmetros opcionais (--max-difference e --image)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-difference)
            MAX_DIFFERENCE="$2"
            shift 2
            ;;
        --image)
            IMAGE="$2"
            shift 2
            ;;
        *)
            echo "Aviso: argumento desconhecido ignorado: $1"
            shift
            ;;
    esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_OUT_DIR="$ROOT_DIR/goldens/labs_per_year"
mkdir -p "$BASE_OUT_DIR"

# Seleciona os arquivos a processar
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
echo " Running LuccME 3.1 Per-Year Goldens in Docker ($IMAGE)"
echo " Selected: ${TARGET_INPUT}"
echo " Output base directory: $BASE_OUT_DIR"
if [ -n "$MAX_DIFFERENCE" ]; then
    echo " Max Difference override: $MAX_DIFFERENCE"
fi
echo "========================================================================"

FAILED_LABS=()
SUCCESS_LABS=()

for lab_file in "${LAB_FILES[@]}"; do
    lab_name="$(basename "$lab_file" .lua)"
    
    # Define o nome de saída (com sufixo se houver variante MD)
    if [ -n "$MAX_DIFFERENCE" ]; then
        run_name="${lab_name}_md${MAX_DIFFERENCE}"
    else
        run_name="${lab_name}"
    fi

    # Localiza o golden de referência de células canônicas
    # Suporta formatos como Lab15_2020.csv, Lab15.csv, lab15_2020.csv, etc.
    lab_num_pattern="${lab_name#lab}"
    cells_file=$(find "$ROOT_DIR/goldens/labs" -maxdepth 1 -type f \( -iname "${lab_name}_*.csv" -o -iname "${lab_name}.csv" \) | head -n 1)

    if [ -z "$cells_file" ] || [ ! -f "$cells_file" ]; then
        echo "==> Skipping $run_name: golden de celulas de referencia nao encontrado em goldens/labs/"
        continue
    fi

    echo -n "==> Running per-year for $run_name... "

    WORK_DIR="$(mktemp -d)"
    SNAPSHOT_FILE="/work/snapshot_per_year.csv"

    # Prepara argumentos para o transform
    TRANSFORM_ARGS=("$lab_file" --out "$WORK_DIR/target_lab.lua" --snapshot "$SNAPSHOT_FILE")
    if [ -n "$MAX_DIFFERENCE" ]; then
        TRANSFORM_ARGS+=(--max-difference "$MAX_DIFFERENCE")
    fi

    # 1. Transforma o lab injetando o gravador per-year
    if ! python3 "$ROOT_DIR/scripts/lab_per_year.py" transform "${TRANSFORM_ARGS[@]}" > "$WORK_DIR/transform.log" 2>&1; then
        echo "FAILED on transform (veja log abaixo)"
        cat "$WORK_DIR/transform.log"
        FAILED_LABS+=("$run_name")
        rm -rf "$WORK_DIR"
        continue
    fi

    # 2. Executa no Docker via xvfb-run
    if docker run --rm \
        --user "$(id -u):$(id -g)" \
        -v "$WORK_DIR":/work \
        "$IMAGE" \
        bash -c "
            xvfb-run -a -s '-screen 0 1280x1024x24' /opt/terrame/bin/terrame -autoclose target_lab.lua
        " > "$WORK_DIR/execution.log" 2>&1; then

        # Verifica se o snapshot CSV foi gerado
        if [ ! -f "$WORK_DIR/snapshot_per_year.csv" ]; then
            echo "FAILED: Snapshot CSV nao foi produzido"
            FAILED_LABS+=("$run_name")
            rm -rf "$WORK_DIR"
            continue
        fi

        # 3. Consolida os dados usando lab_per_year.py consolidate
        CONSOLIDATE_ARGS=(
            --name "$run_name"
            --raw "$WORK_DIR/snapshot_per_year.csv"
            --log "$WORK_DIR/execution.log"
            --cells "$cells_file"
            --source "$lab_file"
            --out-dir "$BASE_OUT_DIR/$run_name"
            --image "$IMAGE"
        )
        if [ -n "$MAX_DIFFERENCE" ]; then
            CONSOLIDATE_ARGS+=(--max-difference "$MAX_DIFFERENCE")
        fi

        if python3 "$ROOT_DIR/scripts/lab_per_year.py" consolidate "${CONSOLIDATE_ARGS[@]}" > "$WORK_DIR/consolidate.log" 2>&1; then
            echo "OK"
            SUCCESS_LABS+=("$run_name")
        else
            echo "FAILED on consolidate"
            cat "$WORK_DIR/consolidate.log"
            FAILED_LABS+=("$run_name")
        fi
    else
        echo "FAILED on Docker run (veja $BASE_OUT_DIR/${run_name}_err.log)"
        FAILED_LABS+=("$run_name")
        cp "$WORK_DIR/execution.log" "$BASE_OUT_DIR/${run_name}_err.log" 2>/dev/null || true
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