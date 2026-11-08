# Pocket Time-Lapse

![teaser](assets/teaser.jpg)

**Pocket Time-Lapse** by Eric M. Chen, Žiga Kovačič, Madhav Aggarwal, and Abe Davis (SIGGRAPH 2025). Project page: [pocket-timelapse.github.io](https://pocket-timelapse.github.io/)

## Time Splatting

![time splatting](assets/time_splatting.jpg)

Time splatting reconstructs a time-lapse from registered panoramas and factorizes it into intrinsic images. It is built on [gsplat](https://github.com/nerfstudio-project/gsplat) and includes an interactive viewer.

Requirements: an NVIDIA GPU, Docker, and the NVIDIA Container Toolkit. The image includes COLMAP 4.1 and one Python 3.12 environment, installed from `requirements.txt`, with PyTorch 2.7.1 (CUDA 12.8), the CUDA extensions, and the [registration](https://github.com/Layer-42/pocket-time-lapse-registration) code from `third_party/registration`. Python 3.12 is used because registration needs `numpy<2`.

## Setup

```bash
git clone --recurse-submodules <this repo>
cd pocket-timelapse
cp .env.example .env
docker compose build
```

In an existing clone, run `git submodule update --init` instead of cloning again.

## Layout

```text
.env                          # DATA_ROOT, DRIVE_FOLDER
third_party/registration/     # registration code (git submodule)
requirements.txt              # the one dependency list for the image
scripts/download.sh           # all datasets
scripts/<step>_<dataset>.sh   # register, train, render per dataset
data/
├── downloads/                # zips from Google Drive
├── raw/<dataset>/            # primary/ and secondary/ captures
├── registered/<dataset>/     # registration output, incl. images/pano_aligned/
└── trained/<dataset>/        # checkpoints, videos, logs
```

## Run

The scripts run inside the container. The repo is mounted at `/workspace/pocket-timelapse`, so everything under `data/` stays on your host.

```bash
docker compose run --rm pocket-timelapse
```

Download all sample datasets once:

```bash
scripts/download.sh          # data/raw/<dataset>
```

Then, for `balcony1` (`balc`):

```bash
scripts/register_balc.sh     # data/registered/balcony1
scripts/train_balc.sh        # data/trained/balcony1
scripts/render_balc.sh       # data/trained/balcony1/videos
```

For `hoyGarageRoofHydrant1`, use the `_hoyg.sh` scripts. You can also run a single step from the host, for example `docker compose run --rm pocket-timelapse scripts/train_balc.sh`.

- Registration uses COLMAP on the GPU and can take over an hour per dataset. Panos that already exist are skipped on a rerun.
- Extra arguments are passed through: `scripts/train_balc.sh --max-steps 200` is a quick smoke test.
- `render_*.sh` uses the newest checkpoint in `data/trained/<dataset>/ckpts`.
- Each step appends to a log in its output folder.
- The Viser viewer is disabled, since it is not reachable from the host unless you publish its port.

To add a dataset, copy the `register`, `train` and `render` scripts of an existing one and change `DATASET`.

## Tuning

Hyperparameters are in `time-splatting/options.py`. These three matter most:

- `time_noise_scale` (default `2.0`): noise added to the time label. Higher values give a smoother time-lapse with less detail.
- `angle_noise_scale` (default `0.1`): noise added to the sun-angle label. Higher values give a smoother time-lapse with less detail.
- `use_bilagrid` (default `False`): bilateral-grid color correction. It sharpens shadows, but can oversmooth real changes in geometry, such as construction.

The other options (learning rates, initial number of Gaussians, and so on) match a standard 3D Gaussian splatting pipeline.
