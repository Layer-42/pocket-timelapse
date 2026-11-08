#!/usr/bin/env bash
# balcony1: train on the aligned panoramas
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DATASET=balcony1
OUT="$DATA_ROOT/trained/$DATASET"

mkdir -p "$OUT"
python time-splatting/train.py default \
    --data-dir "$DATA_ROOT/registered/$DATASET/images/pano_aligned" \
    --result-dir "$OUT" \
    --disable-viewer "$@" \
    2>&1 | tee -a "$OUT/train.log"
