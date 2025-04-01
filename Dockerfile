FROM ubuntu:24.04 AS tpkloss-builder

WORKDIR /usr/src

RUN apt-get update && apt-get install -y \
    git \
    make \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/VQEG/tpkloss.git

WORKDIR /usr/src/tpkloss

RUN make release

FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS ffmpeg-builder

# Install FFmpeg build dependencies
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    git \
    libass-dev \
    libfreetype6-dev \
    libsdl2-dev \
    libtool \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    pkg-config \
    texinfo \
    wget \
    yasm \
    zlib1g-dev \
    nasm \
    libnuma-dev \
    libx264-dev \
    libx265-dev \
    # cuda-npp-12-8 \
    && rm -rf /var/lib/apt/lists/*

# Install nv-codec-headers (ffnvcodec)
WORKDIR /ffmpeg_sources
RUN git clone https://github.com/FFmpeg/nv-codec-headers.git \
    && cd nv-codec-headers \
    && make \
    && make install

# Build FFmpeg with NVIDIA hardware acceleration support
WORKDIR /ffmpeg_sources
RUN git clone https://git.ffmpeg.org/ffmpeg.git \
    && cd ffmpeg \
    && git checkout n7.1 \
    && ./configure \
      --prefix="/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I/ffmpeg_build/include" \
      --extra-ldflags="-L/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --enable-gpl \
      --enable-libass \
      --enable-libfreetype \
      --enable-libx264 \
      --enable-libx265 \
      --enable-nonfree \
      --enable-cuda \
      --enable-cuvid \
      --enable-nvenc \
      --enable-cuda-nvcc \
    && make -j$(nproc) \
    && make install

FROM ubuntu:24.04 AS python-builder

# Install Python build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    checkinstall \
    libreadline-dev \
    libncursesw5-dev \
    libssl-dev \
    libsqlite3-dev \
    tk-dev \
    libgdbm-dev \
    libc6-dev \
    libbz2-dev \
    libffi-dev \
    zlib1g-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Download and build Python 2.7.18
WORKDIR /tmp
RUN wget https://www.python.org/ftp/python/2.7.18/Python-2.7.18.tgz \
    && tar -xvf Python-2.7.18.tgz \
    && cd Python-2.7.18 \
    && ./configure --prefix=/python_build --enable-optimizations \
    && make altinstall

# Get pip for Python 2.7
RUN cd /tmp \
    && wget https://bootstrap.pypa.io/pip/2.7/get-pip.py \
    && /python_build/bin/python2.7 get-pip.py \
    && /python_build/bin/pip2.7 install virtualenv

FROM nvidia/cuda:12.8.1-base-ubuntu24.04 AS final

# Install runtime dependencies
# For streamsim: ffmpeg, tcpdump, tcpreplay, tc
# For helper scripts: bc, parallel
RUN apt-get update && apt-get install -y \
    tcpdump \
    tcpreplay \
    iproute2 \
    iputils-ping \
    net-tools \
    iperf \
    iperf3 \
    bc \
    parallel \
    libass9 \
    libfreetype6 \
    libsdl2-2.0-0 \
    libsndio-dev \
    libva2 \
    libva-drm2 \
    libva-x11-2 \
    libvdpau1 \
    libvorbis0a \
    libx264-164 \
    libx265-199 \
    libnuma1 \
    libxv-dev \
    libxcb1 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    libssl3 \
    libbz2-1.0 \
    && rm -rf /var/lib/apt/lists/*

# Copy tpkloss from the builder stage
COPY --from=tpkloss-builder /usr/src/tpkloss/tpkloss /usr/local/bin/tpkloss

# Copy FFmpeg from the builder stage
COPY --from=ffmpeg-builder /ffmpeg_build /usr/local

# Copy Python from the builder stage
COPY --from=python-builder /python_build /usr/local

# Create symbolic links to make Python and pip easily accessible
RUN ln -s /usr/local/bin/python2.7 /usr/local/bin/python

# Set up application directory and virtualenv
WORKDIR /app/src

RUN python -m virtualenv venv

COPY ./requirements.txt .

RUN ./venv/bin/pip install -r requirements.txt

COPY . .

# Create entrypoint script to activate virtualenv
RUN echo '#!/bin/bash\nsource /app/src/venv/bin/activate\nexec "$@"' > /entrypoint.sh \
    && chmod +x /entrypoint.sh

# Verify installations
RUN echo "FFmpeg version:" && ffmpeg -version | head -n 1 \
    && echo "Python version:" && python --version \
    && echo "Pip version:" && ./venv/bin/pip --version

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
