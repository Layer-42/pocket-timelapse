#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

VENV="${VENV:-.venv}"
export CUDA_HOME="${CUDA_HOME:-/usr/local/cuda}"

uv venv --clear --python 3.12 "$VENV"
PY="$VENV/bin/python"

TORCH_REQS="$(mktemp)"
trap 'rm -f "$TORCH_REQS"' EXIT
grep -E '^(--extra-index-url|torch)' requirements.txt > "$TORCH_REQS"
uv pip install --python "$PY" -r "$TORCH_REQS" setuptools wheel ninja

uv pip install --python "$PY" -r requirements.txt \
    --no-build-isolation-package fused-ssim \
    --no-build-isolation-package fused-bilagrid \
    --no-build-isolation-package gsplat
