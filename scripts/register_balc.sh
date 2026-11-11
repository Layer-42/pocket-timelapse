#!/usr/bin/env bash
# balcony1: register the structured capture into aligned panoramas
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DATASET=balcony1
RAW="$DATA_ROOT/raw/$DATASET"
OUT="$DATA_ROOT/registered"

mkdir -p "$OUT/$DATASET"
python third_party/registration/ptlreg/AlignStructuredDataset.py \
    -p "$RAW/primary" -s "$RAW/secondary" -o "$OUT/" -n "$DATASET" \
    2>&1 | tee -a "$OUT/$DATASET/register.log"
