# Report: Pocket Time-Lapse

We study how a long-term photo capture becomes a continuous time-lapse video. Our case is the construction site `hoyGarageRoofHydrant1` (HOYG): 4.5k phone photos taken over 18 months.

![raw vs aligned](waldek_assets/02_registration/raw_vs_aligned.gif)

The pipeline runs as three scripts, one per section below: registration, training and rendering.

## 1. Registration

### Registration method

A time-lapse needs every frame in the same reference frame as hand-held photos never line up exactly, so a registration step is required to align them.

Two types of images are considered, a **Primary** photo that faces the same part of the scene every time, and a **Secondary** photo covering the area around it extending the field of view.

Registration has five stages:

1. **Create Sessions.** Images are sorted by timestamp, and each primary is grouped with its secondaries.
2. **Features matching.** For each primary, features are extracted and matched with its nearest primaries in time. For each secondary, features are extracted and matched with its nearest neighbours. Two-view geometric verification gives a homography and an inlier count per pair. Colmap GPU-SIFT is used for feature extraction and matching.
3. **Alignment graph.** Images are nodes; each verified pair is an edge with homography $H_{a\to b}$ and a inverse matching cost $c_{a\to b}$. The reference is the most central primary and image $i$ is aligned by composing the edge homographies along its cheapest path to the reference frame $H_{i\to c}$.
4. **Sanity test.** A homography is rejected in two cases: the image is mirrored ($\det H_{2\times2}\le 0$), or it is scaled by more than about 10× in area $\det H < 0.1$ for extreme view changes.
5. **Panorama compositing.** The canvas is the reference view with a 50% margin on each side. Each accepted secondary is warped onto the canvas, colour-matched to the warped primary, and added with alpha weights. The primary is added last, and the sum is divided by the total alpha to give the final panorama composite.

The Panos will be used as input for the training and rendering stages.

### HOYG Registration

We register the HOYG images using the following script:

```bash
scripts/register_hoyg.sh
```

The registered images and panos are saved under `data/registered/hoyGarageRoofHydrant1/images/pano_aligned/`.

- **Input.** 409 primaries and 4,142 secondaries. Timestamps are parsed from file names such as `2023-07-19T11:12:19.jpeg`.

- **Counts.** Registration yields 409 sessions with a canvas of 2880×2160 with uncovered pixels appearing black.

On our workstation (Intel Core i9-12900H, 20 threads, 16 GiB RAM, RTX 3070), feature matching took 27 min 35 s and panorama compositing took 1 h 13 min.

| | 2023-08-16 | 2023-12-03 | 2024-04-19 | 2024-10-07 |
| --- | --- | --- | --- | --- |
| **raw** | ![raw primary 2023-08-16T13:59:35](waldek_assets/01_raw/primary/2023-08-16T13-59-35.jpeg) | ![raw primary 2023-12-03T12:21:05](waldek_assets/01_raw/primary/2023-12-03T12-21-05.jpeg) | ![raw primary 2024-04-19T14:47:39](waldek_assets/01_raw/primary/2024-04-19T14-47-39.jpeg) | ![raw primary 2024-10-07T10:07:07](waldek_assets/01_raw/primary/2024-10-07T10-07-07.jpeg) |
| **aligned** | ![aligned panorama 2023-08-16T13:59:35](waldek_assets/02_registration/pano_aligned/2023-08-16T13-59-35.jpg) | ![aligned panorama 2023-12-03T12:21:05](waldek_assets/02_registration/pano_aligned/2023-12-03T12-21-05.jpg) | ![aligned panorama 2024-04-19T14:47:39](waldek_assets/02_registration/pano_aligned/2024-04-19T14-47-39.jpg) | ![aligned panorama 2024-10-07T10:07:07](waldek_assets/02_registration/pano_aligned/2024-10-07T10-07-07.jpg) |

<p align="center">
Aligned panoramas over the capture period.

<img src="waldek_assets/02_registration/aligned_panos.gif" alt="aligned panos" width="600">
</p>

## 2. Training

### Training method

**Time Splatting** fits a continuous function of time that reproduces a stack of input Panos using gaussian splatting with a time axis and a separate shading component.

- **Geometry**: The camera is orthographic and fixed where the  gaussians start as points spread over the image plane creating a 2D splatting representation of the scene.

- Each capture day maps to $t\in[0,1]$. Days are spaced evenly, so long gaps without captures do not consume model capacity.

- Sun azimuth and altitude are computed from the timestamp and location, and normalised to $[0,1]$.

- **Albedo Gaussians**: each Gaussian has a position, scale, rotation, opacity, an RGB colour and a 1-D temporal Gaussian $(\mu_t, \sigma_t)$. At query time $t$, its opacity is modulated by the temporal Gaussian: $\alpha_i(t) = \alpha_i \exp\!\Big(-\tfrac12 \big(\tfrac{t-\mu_{t,i}}{\sigma_{t,i}}\big)^2\Big)$, each Gaussian therefore exists only within a time window.

- **Shading Gaussians**: A second, independent set. Each has a grayscale colour and a 3-D temporal Gaussian over $\mathbf{u} = (t, \phi_\text{az}, \theta_\text{alt})$ with one scale per axis. Shading depends on the sun's position as well as the date, which separates shadows from material change.

**Image formation.** The rendered image is simply albedo x shading, masked by the registration masking $M$ ignoring pixels outside the panorama:

$$\hat I(t,\phi,\theta) = M\,A(t)\cdot S(t,\phi,\theta)$$

**Optimisation.** The objective is $\mathcal{L} = 0.8\,\lVert \hat I - I\rVert_1 + 0.2\,(1-\text{SSIM}(\hat I, I))$ minimised with Adam. Densification clones, splits and prunes Gaussians for a fixed max Gaussian count.

**Transient and persistent content.** To separate transient from persistent content, the model relies on the temporal jittering and the time windows of the Gaussians. Each time label moves by about ±2 capture days ($\epsilon\,\Delta t \cdot s_t$). Transient content lasts only a few days, so it blurs into the background. Persistent change lasts many days, so the time windows keep it.

| input | render |
|---|---|
| ![reconstruction 2024-10-07T10:07:07 input](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_input.jpg) | ![reconstruction 2024-10-07T10:07:07 render](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_render.jpg) |

- **Removed:** the lift, the workers  and the cloud.
- **Kept:** the facade, windows, and scaffolding ... etc.

### HOYG Training

```bash
scripts/train_hoyg.sh
```

The run takes 30k steps. The loss curves are shown below.

<div align="center">

| Total loss | L1 | 1 − SSIM |
|---|---|---|
| ![loss total](waldek_assets/03_training/loss_total.png) | ![loss l1](waldek_assets/03_training/loss_l1.png) | ![loss ssim](waldek_assets/03_training/loss_ssim.png) |

</div>

The Gaussian count grows during training and stops at 15k steps, when densification ends.

<p align="center">
<img src="waldek_assets/03_training/num_gaussians.png" alt="number of gaussians" width="480">
</p>

<div align="center">

| Checkpoint | Time | Albedo Gaussians | Peak GPU memory |
| --- | --- | --- | --- |
| 5k | 6.0 min | 0.30 M | 1.26 GB |
| 10k | 14.0 min | 0.99 M | 1.77 GB |
| 20k | 34.3 min | 2.05 M | 3.05 GB |
| 30k | 55.3 min | 2.05 M | 3.05 GB |

</div>

<p align="center">
<img src="waldek_assets/03_training/progress_2x2.gif" alt="training progress" width="720">
</p>

## 3. Rendering & Eval

Albedo depends on time $t$. Shading depends on time $t$, sun azimuth $\phi$ and sun altitude $\theta$. We sweep $t$ across the full time span with the sun fixed at one time of day, and query albedo and shading at the same $t$ and sun position.

### HOYG Rendering

```bash
scripts/render_hoyg.sh
```

**Results.** Composite, albedo and shading over the full time span:

![render albedo shading](waldek_assets/04_rendering/render_albedo_shading.gif)

**Trajectory frames at two sample days** (sun angle at 10:00):

| | render | albedo | shading |
| --- | --- | --- | --- |
| **2023-12-03** | ![trajectory 2023-12-03 render](waldek_assets/04_rendering/trajectory/2023-12-03_render.jpg) | ![trajectory 2023-12-03 albedo](waldek_assets/04_rendering/trajectory/2023-12-03_albedo.jpg) | ![trajectory 2023-12-03 shading](waldek_assets/04_rendering/trajectory/2023-12-03_shading.jpg) |
| **2024-10-07** | ![trajectory 2024-10-07 render](waldek_assets/04_rendering/trajectory/2024-10-07_render.jpg) | ![trajectory 2024-10-07 albedo](waldek_assets/04_rendering/trajectory/2024-10-07_albedo.jpg) | ![trajectory 2024-10-07 shading](waldek_assets/04_rendering/trajectory/2024-10-07_shading.jpg) |

**Input vs reconstruction.** Each input panorama is rendered at its own capture time and sun angle $(t, \phi, \theta)$:

| | input | render | albedo | shading |
| --- | --- | --- | --- | --- |
| **2023-12-03** | ![reconstruction 2023-12-03T12:21:05 input](waldek_assets/04_rendering/reconstruction/2023-12-03T12-21-05_input.jpg) | ![reconstruction 2023-12-03T12:21:05 render](waldek_assets/04_rendering/reconstruction/2023-12-03T12-21-05_render.jpg) | ![reconstruction 2023-12-03T12:21:05 albedo](waldek_assets/04_rendering/reconstruction/2023-12-03T12-21-05_albedo.jpg) | ![reconstruction 2023-12-03T12:21:05 shading](waldek_assets/04_rendering/reconstruction/2023-12-03T12-21-05_shading.jpg) |
| **2024-10-07** | ![reconstruction 2024-10-07T10:07:07 input](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_input.jpg) | ![reconstruction 2024-10-07T10:07:07 render](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_render.jpg) | ![reconstruction 2024-10-07T10:07:07 albedo](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_albedo.jpg) | ![reconstruction 2024-10-07T10:07:07 shading](waldek_assets/04_rendering/reconstruction/2024-10-07T10-07-07_shading.jpg) |

Metrics are computed on all panoramas, inside the alpha mask:

| Metric (masked) | Value |
| --- | --- |
| PSNR | 19.16 dB |
| SSIM | 0.758 |
| LPIPS (AlexNet, half resolution) | 0.352 |

![psnr per frame](waldek_assets/05_remarks/psnr_per_frame.png)

![ssim per frame](waldek_assets/05_remarks/ssim_per_frame.png)

## 4. Remarks and notes

- PSNR looks low because the model is meant to drop transient content: the lift, the workers and the pickup truck disappear, and the clouds are averaged into a calm sky.
- SSIM can look too good on sessions with little coverage as in 2024-02-03 with 25% canvas coverage.
- The more secondaries a session has, the more of the canvas its panorama fills.
- You can `--skip-matching` in `register_hoyg.sh` to skip registration COLMAP database from an earlier run.
- The sun position is computed for America/New York (`sun_angle()`), won't reflect the actual sun position for other scenes.
- `time_noise_scale` (default 2.0) sets how much the model smooths over time. Higher values remove more transients but also blur real changes, trade-off between stability and fidelity.
- `angle_noise_scale` (default 0.1) does the same along the sun angles, trading shadow detail for stability.
- `use_bilagrid` (default off) adds a per-image colour correction. It sharpens shadows but can absorb real changes in the scene.
- `refine_stop_iter` (default 15k) is the step where densification ends. After it, no Gaussians are added or removed, but training continues to 30k with the same loss and label noise: every Gaussian keeps refining its position, shape, opacity, colour and time window while the position learning rate decays. Most of the visible sharpening happens before 20k.
- Capture habits matter most. Primaries: same spot, framing and zoom, at a regular rhythm, in daylight across different times of day. Secondaries: about 10 per session, each overlapping its neighbours.
