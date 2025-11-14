FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    wget \
    file \
    build-essential \
    libncurses5-dev \
    gawk \
    git \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /builder

RUN wget https://downloads.openwrt.org/releases/24.10.0/targets/mediatek/filogic/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.xz && \
    tar -xf openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.xz && \
    rm openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64.tar.xz

WORKDIR /builder/openwrt-imagebuilder-24.10.0-mediatek-filogic.Linux-x86_64

CMD ["/bin/bash"]

