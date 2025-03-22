FROM python:2.7.18-slim AS tpkloss-build

WORKDIR /usr/src

RUN apt-get update && apt-get install -y \
    git \
    make \
    gcc \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/VQEG/tpkloss.git

WORKDIR /usr/src/tpkloss

RUN make release

FROM python:2.7.18-slim AS base

COPY --from=tpkloss-build /usr/src/tpkloss/tpkloss /usr/local/bin/tpkloss

# Install requirements:
# For streamsim: ffmpeg, tcpdump, tcpreplay, tc
# For helper scripts: bc, parallel
RUN apt-get update && apt-get install -y \
    ffmpeg \
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

WORKDIR /usr/src/app

COPY ./requirements.txt .

RUN pip install -r ./requirements.txt

CMD ["bash"]
