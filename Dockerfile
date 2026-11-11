# syntax=docker/dockerfile:1

FROM nvidia/cuda:12.8.0-devel-ubuntu22.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG COLMAP_VERSION=4.1.0
ARG MAX_JOBS=4

# Turing to Blackwell. Override with --build-arg CUDA_ARCHITECTURES="80" etc.
ARG CUDA_ARCHITECTURES="75;80;86;89;90;100;120"
ARG TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6;8.9;9.0;10.0;12.0+PTX"

ENV CUDA_HOME=/usr/local/cuda \
    CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES} \
    TORCH_CUDA_ARCH_LIST=${TORCH_CUDA_ARCH_LIST} \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

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

# Ubuntu 22.04 ships CMake 3.22, which is too old for COLMAP
RUN python3 -m pip install --no-cache-dir \
    "cmake>=3.27" ninja uv \
    && cmake --version

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

# Python 3.12: registration needs numpy<2, which has no wheels for 3.13
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python \
    UV_LINK_MODE=copy \
    UV_INDEX_STRATEGY=unsafe-best-match \
    UV_HTTP_TIMEOUT=600 \
    UV_HTTP_RETRIES=10 \
    UV_CONCURRENT_DOWNLOADS=4 \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace/pocket-timelapse

COPY requirements.txt ./
COPY third_party/registration third_party/registration
COPY scripts/install.sh scripts/install.sh
RUN --mount=type=cache,target=/root/.cache/uv \
    VENV=/opt/venv bash scripts/install.sh

# Non-recursive chown: a recursive one would copy the venv layers
RUN groupadd --gid ${GID} ${USERNAME} \
    && useradd \
        --uid ${UID} \
        --gid ${GID} \
        --create-home \
        --shell /bin/bash \
        ${USERNAME} \
    && mkdir -p /workspace/pocket-timelapse \
    && chown ${USERNAME}:${USERNAME} /workspace /workspace/pocket-timelapse

USER ${USERNAME}

CMD ["/bin/bash"]
