#!/usr/bin/env bash
# Install the Python environment. Needs an NVIDIA GPU and nvcc on PATH.
# Run:  ./scripts/install.sh
set -e
cd "$(dirname "$0")/.."

command -v nvcc >/dev/null || { echo "nvcc not found: install the CUDA toolkit first."; exit 1; }

if ! command -v uv >/dev/null; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

# Build the CUDA extensions for this GPU only.
TORCH_CUDA_ARCH_LIST=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -n 1)
export TORCH_CUDA_ARCH_LIST

uv sync --frozen

# Fail here, not in the middle of training, if the CUDA extensions do not import.
uv run --frozen python -c "import torch, gsplat, fused_ssim, fused_bilagrid; print('torch', torch.__version__, 'cuda', torch.cuda.is_available())"
