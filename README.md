# Pocket Time-Lapse

![teaser](assets/teaser.jpg)

**Pocket Time-Lapse** by Eric M. Chen, Žiga Kovačič, Madhav Aggarwal, and Abe Davis (SIGGRAPH 2025). Project page: [pocket-timelapse.github.io](https://pocket-timelapse.github.io/)

## Time Splatting

![time splatting](assets/time_splatting.jpg)

Time splatting reconstructs a time-lapse from registered panoramas and factorizes it into intrinsic images.

Requirements:

- Docker
- COLMAP 4.1
- Python 3.12
- PyTorch 2.7.1 (CUDA 12.8)
- gsplat

## Setup

```bash
git clone --recurse-submodules https://github.com/Layer-42/pocket-timelapse.git
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

The scripts run inside the container at `/workspace/pocket-timelapse`

```bash
docker compose run --rm pocket-timelapse
```

Download all sample datasets once:

```bash
scripts/download.sh          # data/raw/<dataset>
```

Then, for `hoyGarageRoofHydrant1` (`hoyg`):

```bash
scripts/register_hoyg.sh     # data/registered/hoyGarageRoofHydrant1
scripts/train_hoyg.sh        # data/trained/hoyGarageRoofHydrant1
scripts/render_hoyg.sh       # data/trained/hoyGarageRoofHydrant1/videos
```

Other datasets follow the same pattern with their own suffix, for example `balc` for `balcony1`.

## Tuning

Hyperparameters are in `time-splatting/options.py`. These three matter most:

- `time_noise_scale` (default `2.0`): noise added to the time label. Higher values give a smoother time-lapse with less detail.
- `angle_noise_scale` (default `0.1`): noise added to the sun-angle label. Higher values give a smoother time-lapse with less detail.
- `use_bilagrid` (default `False`): bilateral-grid color correction. It sharpens shadows, but can oversmooth real changes in geometry, such as construction.

The other options (learning rates, initial number of Gaussians, and so on) match a standard 3D Gaussian splatting pipeline.
