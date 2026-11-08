#!/usr/bin/env bash
# Download all sample datasets and extract them into data/raw/<dataset>
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a

DL="$DATA_ROOT/downloads"
mkdir -p "$DL" "$DATA_ROOT/raw"
gdown --folder --continue "$DRIVE_FOLDER" -O "$DL"

for zip in "$DL"/*.zip; do
    name=$(basename "$zip" .zip)
    unzip -q -n "$zip" -x '__MACOSX/*' '*.DS_Store' -d "$DATA_ROOT/raw"
    echo "$name: $(ls "$DATA_ROOT/raw/$name/primary" | wc -l) primary, $(ls "$DATA_ROOT/raw/$name/secondary" | wc -l) secondary"
done
