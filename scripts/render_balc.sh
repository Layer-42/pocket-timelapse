#!/usr/bin/env bash
# balcony1: render from the newest checkpoint
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DATASET=balcony1
OUT="$DATA_ROOT/trained/$DATASET"
CKPT=$(find "$OUT/ckpts" -name 'ckpt_*.pt' 2>/dev/null | sort -V | tail -n 1)
[ -n "$CKPT" ] || { echo "No checkpoint in $OUT/ckpts; run train_balc.sh first" >&2; exit 1; }

python time-splatting/train.py default \
    --data-dir "$DATA_ROOT/registered/$DATASET/images/pano_aligned" \
    --result-dir "$OUT" \
    --ckpt "$CKPT" \
    --disable-viewer \
    2>&1 | tee -a "$OUT/render.log"
