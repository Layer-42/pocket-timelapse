
# syntax=docker/dockerfile:1

FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG COLMAP_VERSION=4.1.0
ARG MAX_JOBS=4

# GPU architectures: Turing, Ampere, Ada, Hopper, Blackwell
ARG CUDA_ARCHITECTURES="75;80;86;89;90;100;120"
ARG TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0;10.0;12.0+PTX"

ENV CUDA_HOME=/usr/local/cuda \
    CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates unzip \
    build-essential ninja-build pkg-config \
    python3 python3-pip python3-dev \
    libboost-program-options-dev libboost-graph-dev libboost-system-dev \
    libeigen3-dev libopenimageio-dev openimageio-tools libopencv-dev \
    libmetis-dev libgoogle-glog-dev \
    libsqlite3-dev libssl-dev \
    libcgal-dev libceres-dev libsuitesparse-dev \
    libcurl4-openssl-dev libopenblas-openmp-dev \
    libgl-dev libglew-dev libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Install CMake and uv
RUN python3 -m pip install --no-cache-dir \
    "cmake>=3.27" ninja uv

# Build COLMAP
RUN curl -fsSL \
        "https://github.com/colmap/colmap/archive/refs/tags/${COLMAP_VERSION}.tar.gz" \
        -o /tmp/colmap.tar.gz \
    && mkdir -p /tmp/colmap \
    && tar -xzf /tmp/colmap.tar.gz \
        -C /tmp/colmap --strip-components=1 \
    && cmake -S /tmp/colmap -B /tmp/colmap/build -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DCUDA_ENABLED=ON \
        -DCMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES}" \
        -DGUI_ENABLED=OFF \
        -DBLA_VENDOR=OpenBLAS \
    && cmake --build /tmp/colmap/build -j ${MAX_JOBS} \
    && cmake --install /tmp/colmap/build \
    && ldconfig \
    && rm -rf /tmp/colmap /tmp/colmap.tar.gz


FROM base AS app

ARG USERNAME=pocket-timelapse
ARG UID=1000
ARG GID=1000

ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_LINK_MODE=copy \
    UV_INDEX_STRATEGY=unsafe-best-match \
    UV_HTTP_TIMEOUT=600 \
    UV_HTTP_RETRIES=10 \
    UV_CONCURRENT_DOWNLOADS=4 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace/pocket-timelapse

# Create Python 3.12 environment
RUN uv venv --python 3.12 --seed /opt/venv

# Install PyTorch first
COPY requirements.txt ./

RUN --mount=type=cache,target=/root/.cache/uv \
    grep -E '^(--extra-index-url|torch)' requirements.txt \
        > /tmp/torch.txt \
    && uv pip install -r /tmp/torch.txt \
        setuptools wheel ninja \
    && rm /tmp/torch.txt

# Install project dependencies and compile gsplat from source
COPY third_party/registration third_party/registration

RUN --mount=type=cache,target=/root/.cache/uv \
    MAX_JOBS=8 uv pip install -r requirements.txt \
        --no-build-isolation-package fused-ssim \
        --no-build-isolation-package fused-bilagrid \
        --no-build-isolation-package gsplat \
        --no-binary gsplat

# Non-root user
RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd \
        --uid ${UID} \
        --gid ${GID} \
        --create-home \
        --shell /bin/bash \
        ${USERNAME} \
    && chown ${USERNAME}:${USERNAME} \
        /workspace /workspace/pocket-timelapse

USER ${USERNAME}

CMD ["/bin/bash"]
