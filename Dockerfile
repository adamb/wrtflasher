FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget \
    file \
    build-essential \
    libncurses5-dev \
    gawk \
    git \
    python3 \
    python3-distutils \
    unzip \
    zstd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /builder

COPY downloads/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst .
RUN tar --zstd -xf openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst && \
    rm openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.zst

WORKDIR /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64

CMD ["/bin/bash"]
