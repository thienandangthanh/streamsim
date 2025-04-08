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

FROM jrottenberg/ffmpeg:7.1.1-nvidia2404 AS final

# Install runtime dependencies
# For streamsim: tcpdump, tcpreplay, tc
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
    && rm -rf /var/lib/apt/lists/*

# Copy tpkloss from the builder stage
COPY --from=tpkloss-builder /usr/src/tpkloss/tpkloss /usr/local/bin/tpkloss

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
