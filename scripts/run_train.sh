#!/usr/bin/env bash
# Train on a pano_aligned folder from the registration repo. Opens the viewer when done.
# Edit the settings below, then run:  ./scripts/run_train.sh
set -eo pipefail
cd "$(dirname "$0")/.."

NAME=balcony1                                                               # output folder: results/$NAME
DATA=../pocket-time-lapse-registration/results/$NAME/images/pano_aligned    # folder of aligned panos

mkdir -p "results/$NAME"
uv run --frozen python time-splatting/train.py mcmc \
    --data_dir "$DATA" \
    --result_dir "results/$NAME" 2>&1 | tee -a "results/$NAME/train.log"
