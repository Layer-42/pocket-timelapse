#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")/.."

# Hydrant 
NAME=hoyGarageRoofHydrant1 
DATA=../pocket-time-lapse-registration/results/$NAME/images/pano_aligned   

mkdir -p "results/$NAME"
uv run --frozen python time-splatting/train.py default \
    --data_dir "$DATA" \
    --result_dir "results/$NAME" 2>&1 | tee -a "results/$NAME/train.log"
