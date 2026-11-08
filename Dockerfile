FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=pocket-timelapse
ARG UID=1000
ARG GID=1000
ARG COLMAP_VERSION=4.1.0
ARG MAX_JOBS=4

ENV TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6+PTX" \
    CUDA_HOME=/usr/local/cuda \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates \
    build-essential ninja-build pkg-config \
    python3 python3-pip python3-dev \
    libboost-program-options-dev libboost-graph-dev libboost-system-dev \
    libeigen3-dev libopenimageio-dev openimageio-tools \
    libmetis-dev libgoogle-glog-dev libgtest-dev \
    libsqlite3-dev libglew-dev libssl-dev \
    qtbase5-dev libqt5opengl5-dev libqt5svg5-dev \
    libcgal-dev libceres-dev libsuitesparse-dev \
    libcurl4-openssl-dev libopenblas-openmp-dev \
    libopencv-dev libgl1 libglib2.0-0 \
    ffmpeg libimage-exiftool-perl \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 22.04 ships CMake 3.22; COLMAP's dependencies need >= 3.24
RUN python3 -m pip install --upgrade pip setuptools wheel \
    && python3 -m pip install --upgrade "cmake>=3.27" ninja \
    && cmake --version

RUN curl -fsSL \
    https://github.com/colmap/colmap/archive/refs/tags/${COLMAP_VERSION}.tar.gz \
    -o /tmp/colmap.tar.gz \
    && mkdir -p /tmp/colmap \
    && tar -xzf /tmp/colmap.tar.gz -C /tmp/colmap --strip-components=1 \
    && cmake -S /tmp/colmap -B /tmp/colmap/build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_ENABLED=ON \
        -DCMAKE_CUDA_ARCHITECTURES="75;80;86" \
        -DGUI_ENABLED=OFF \
        -DBLA_VENDOR=OpenBLAS \
    && cmake --build /tmp/colmap/build -j ${MAX_JOBS} \
    && cmake --install /tmp/colmap/build \
    && ldconfig \
    && rm -rf /tmp/colmap /tmp/colmap.tar.gz


FROM base AS app

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=pocket-timelapse
ARG UID=1000
ARG GID=1000
ARG COLMAP_VERSION=4.1.0
ARG MAX_JOBS=4

RUN apt-get update && apt-get install -y --no-install-recommends unzip \
    && rm -rf /var/lib/apt/lists/*

# One env for training and registration. Python 3.12 because registration
# needs numpy<2, which has no wheels for 3.13.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_LINK_MODE=copy \
    UV_INDEX_STRATEGY=unsafe-best-match \
    UV_HTTP_TIMEOUT=600 \
    UV_HTTP_RETRIES=10 \
    UV_CONCURRENT_DOWNLOADS=4
RUN python3 -m pip install uv \
    && uv venv --python 3.12 --seed /opt/venv
ENV VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

WORKDIR /workspace/pocket-timelapse

# torch first: fused-ssim, fused-bilagrid and gsplat import it at build time
COPY requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/uv \
    grep -E '^(--extra-index-url|torch)' requirements.txt > /tmp/torch.txt \
    && uv pip install -r /tmp/torch.txt setuptools wheel ninja \
    && rm /tmp/torch.txt

# The editable install points at /workspace/pocket-timelapse/third_party/registration,
# which the compose bind mount replaces with the host submodule at runtime.
COPY third_party/registration third_party/registration
RUN --mount=type=cache,target=/root/.cache/uv \
    uv pip install -r requirements.txt \
        --no-build-isolation-package fused-ssim \
        --no-build-isolation-package fused-bilagrid \
        --no-build-isolation-package gsplat

# Non-recursive chown: a recursive one would copy the venv layers
RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd --uid ${UID} --gid ${GID} \
        --create-home --shell /bin/bash ${USERNAME} \
    && mkdir -p /workspace/pocket-timelapse \
    && chown ${USERNAME}:${USERNAME} /workspace /workspace/pocket-timelapse

USER ${USERNAME}

WORKDIR /workspace/pocket-timelapse

CMD ["/bin/bash"]
