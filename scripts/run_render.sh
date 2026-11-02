#!/usr/bin/env bash
# Render the trajectory video from the newest checkpoint of a training run. Opens the viewer when done.
# Edit the settings below, then run:  ./scripts/run_render.sh
# Output: results/$NAME/videos/traj_<step>.mp4
set -eo pipefail
cd "$(dirname "$0")/.."

NAME=balcony1                                                               # result folder: results/$NAME
DATA=../pocket-time-lapse-registration/results/$NAME/images/pano_aligned    # same folder used for training
CKPT=$(find "results/$NAME/ckpts" -name 'ckpt_*.pt' | sort -V | tail -n 1)  # newest checkpoint

mkdir -p "results/$NAME"
uv run --frozen python time-splatting/train.py mcmc \
    --data_dir "$DATA" \
    --result_dir "results/$NAME" \
    --ckpt "$CKPT" 2>&1 | tee -a "results/$NAME/render.log"
