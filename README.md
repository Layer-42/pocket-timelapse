# Pocket Time-Lapse

![teaser](assets/teaser.jpg)

**Pocket Time-Lapse** by Eric M. Chen, Žiga Kovačič, Madhav Aggarwal, and Abe Davis (SIGGRAPH 2025). Project page: [pocket-timelapse.github.io](https://pocket-timelapse.github.io/)

## Time Splatting

![time splatting](assets/time_splatting.jpg)

Time splatting reconstructs a time-lapse from registered panoramas and factorizes it into intrinsic images. It is built on [gsplat](https://github.com/nerfstudio-project/gsplat) and includes an interactive viewer.

Requirements: an NVIDIA GPU with the CUDA toolkit (`nvcc` on your PATH), and Ubuntu. Tested with Python 3.13, PyTorch 2.7.1, and gsplat 1.5.2.

## Install

```bash
./scripts/install.sh
```

This installs the Python environment with [uv](https://docs.astral.sh/uv/) and builds the CUDA extensions for your GPU. The code is in `time-splatting/`. The install files are in the repository root.

Pip alternative (install PyTorch first):

```bash
pip install torch torchvision
pip install -r requirements.txt --no-build-isolation
```

## Train

The input is the `pano_aligned` folder from the [registration repo](../pocket-time-lapse-registration), at `results/<NAME>/images/pano_aligned`. Keep the two repos side by side:

```
pocket-time-lapse-registration/
pocket-timelapse/
```

Set `NAME` and `DATA` at the top of `scripts/run_train.sh`, then run it from this repo's root:

```bash
./scripts/run_train.sh
```

Training uses MCMC, writes to `results/<NAME>/`, and opens the Viser viewer when it finishes. Press Ctrl+C to stop the viewer. The log is `train.log`.

To change the training options, call `train.py` directly from the repo root:

```bash
uv run --frozen python time-splatting/train.py mcmc --data_dir /path/to/pano_aligned --result_dir results/balcony1
```

- `mcmc` or `default`: densification strategy. `mcmc` is recommended.
- `--data_dir`: pano folder (required).
- `--result_dir`: output folder. Defaults to `results/<name of data_dir>`.
- `--disable_viewer`: exit without opening the viewer.

## Render

Set `NAME` and `DATA` at the top of `scripts/run_render.sh`, then run it:

```bash
./scripts/run_render.sh
```

This renders from the newest checkpoint in `results/<NAME>/ckpts` to `results/<NAME>/videos/traj_<step>.mp4`, and opens the viewer. The log is `render.log`.

To render from a specific checkpoint, pass `--ckpt` to `train.py`:

```bash
uv run --frozen python time-splatting/train.py mcmc --data_dir /path/to/pano_aligned --result_dir results/balcony1 --ckpt results/balcony1/ckpts/<step>.pt
```

## Tuning

Hyperparameters are in `time-splatting/options.py`. These three matter most:

- `time_noise_scale` (default `2.0`): noise added to the time label. Higher values give a smoother time-lapse with less detail.
- `angle_noise_scale` (default `0.1`): noise added to the sun-angle label. Higher values give a smoother time-lapse with less detail.
- `use_bilagrid` (default `False`): bilateral-grid color correction. It sharpens shadows, but can oversmooth real changes in geometry, such as construction.

The other options (learning rates, initial number of Gaussians, and so on) match a standard 3D Gaussian splatting pipeline.
